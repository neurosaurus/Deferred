//
//  NSProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

// MARK: - Backports

private struct KVO {
    static var context = false
    enum KeyPath: String {
        case completedUnitCount
        case totalUnitCount
        case localizedDescription
        case localizedAdditionalDescription
        case cancellable
        case pausable
        case cancelled
        case paused
        case kind
        static let all: [KeyPath] = [ .completedUnitCount, .totalUnitCount, .localizedDescription, .localizedAdditionalDescription, .cancellable, .pausable, .cancelled, .paused, .kind ]
    }
}

private final class ProxyProgress: NSProgress {

    let original: NSProgress

    init(cloning original: NSProgress) {
        self.original = original
        super.init(parent: .currentProgress(), userInfo: nil)
        attach()
    }

    deinit {
        detach()
    }

    func attach() {
        for keyPath in KVO.KeyPath.all {
            original.addObserver(self, forKeyPath: keyPath.rawValue, options: [.Initial, .New], context: &KVO.context)
        }

        if NSProgress.currentProgress()?.cancelled == true {
            original.cancel()
        } else {
            cancellationHandler = original.cancel
        }

        if #available(OSX 10.11, iOS 9.0, *), NSProgress.currentProgress()?.paused == true {
            original.pause()
        } else {
            pausingHandler = original.pause
            if #available(OSX 10.11, iOS 9.0, *) {
                resumingHandler = original.resume
            }
        }
    }

    func detach() {
        for keyPath in KVO.KeyPath.all {
            original.removeObserver(self, forKeyPath: keyPath.rawValue, context: &KVO.context)
        }

        cancellationHandler = nil
        pausingHandler = nil
        if #available(OSX 10.11, iOS 9.0, *) {
            resumingHandler = nil
        }
    }

    override func replacementObjectForCoder(aCoder: NSCoder) -> AnyObject? {
        return original
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch (keyPath, context) {
        case (KVO.KeyPath.cancelled.rawValue?, &KVO.context):
            guard change?[NSKeyValueChangeNewKey] as? Bool == true else { return }
            cancellationHandler = nil
            cancel()
        case (KVO.KeyPath.paused.rawValue?, &KVO.context):
            if change?[NSKeyValueChangeNewKey] as? Bool == true {
                pausingHandler = nil
                pause()
                if #available(OSX 10.11, iOS 9.0, *) {
                    resumingHandler = original.resume
                }
            } else if #available(OSX 10.11, iOS 9.0, *) {
                resumingHandler = nil
                resume()
                pausingHandler = original.pause
            }
        case (let keyPath?, &KVO.context):
            setValue(change?[NSKeyValueChangeNewKey], forKeyPath: keyPath)
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    @objc static func keyPathsForValuesAffectingUserInfo() -> Set<String> {
        return [ "original.userInfo" ]
    }

    #if swift(>=2.3)
    override var userInfo: [String : AnyObject] {
        return original.userInfo
    }
    #else
    override var userInfo: [NSObject : AnyObject] {
        return original.userInfo
    }
    #endif

    override func setUserInfoObject(object: AnyObject?, forKey key: String) {
        original.setUserInfoObject(object, forKey: key)
    }

}

extension NSProgress {

    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// Send `isOrphaned: false` if the iOS 9 behavior cannot be trusted (i.e.,
    /// `progress` is not guaranteed to have no parent).
    @nonobjc func adoptChild(progress: NSProgress, orphaned canAdopt: Bool, pendingUnitCount: Int64) {
        if #available(OSX 10.11, iOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
        } else if NSProgress.currentProgress() !== self {
            becomeCurrentWithPendingUnitCount(pendingUnitCount)
            defer { resignCurrent() }
            _ = ProxyProgress(cloning: progress)
        } else {
            _ = ProxyProgress(cloning: progress)
        }
    }

}

// MARK: - Convenience initializers

extension NSProgress {

    @nonobjc convenience init(discreteWithCount totalUnitCount: Int64) {
        self.init(parent: nil, userInfo: nil)
        self.totalUnitCount = totalUnitCount
    }

    @nonobjc convenience init(indefinite: ()) {
        self.init(discreteWithCount: -1)
        cancellable = false
    }

    @nonobjc convenience init(noWork: ()) {
        self.init(discreteWithCount: 0)
        completedUnitCount = 1
        cancellable = false
        pausable = false
    }

    // A simple indeterminate progress with a completion block.
    @nonobjc convenience init<Future: FutureType>(future: Future, cancellation: ((Void) -> Void)?) {
        self.init(discreteWithCount: future.isFilled ? 0 : -1)

        if let cancellation = cancellation {
            cancellationHandler = cancellation
        } else {
            cancellable = false
        }

        future.upon { [weak self] _ in
            self?.completedUnitCount = 1
        }
    }

}

// MARK: - Task extension

/**
 Both Task<Value> and NSProgress operate compose over implicit trees, but their
 ordering is reversed. You call map or flatMap on a Task to schedule follow-up
 work, which looks a lot like chaining; a progress tree has a parent-child
 approach. These are compatible: Task adopts progress instances given to it,
 creating a root node implicitly used by chaining calls.
 **/

private let NSProgressTaskRootLockKey = "com_bignerdranch_Deferred_taskRootLock"

extension NSProgress {

    /// `true` if the progress is a wrapper progress created by `Task<Value>`
    private var isTaskRoot: Bool {
        return userInfo[NSProgressTaskRootLockKey] != nil
    }

    static func extendingRoot(for progress: NSProgress) -> NSProgress {
        if progress.isTaskRoot || progress === NSProgress.currentProgress() {
            // Task<Value> has already taken care of this at a deeper level.
            return progress
        } else if let root = NSProgress.currentProgress().flatMap({ return $0.isTaskRoot ? $0 : nil }) {
            // We're in a `extendingTask(unitCount:body:)` block, append it.
            root.adoptChild(progress, orphaned: true, pendingUnitCount: 1)
            return root
        } else {
            // Otherwise, wrap it up as a Task<Value>-marked progress.
            return NSProgress(taskRootFor: progress, orphaned: true)
        }
    }

    /// Create a progress for the root of an implicit chain of tasks.
    @nonobjc convenience init(taskRootFor progress: NSProgress, orphaned: Bool) {
        self.init(discreteWithCount: 1)
        setUserInfoObject(NSLock(), forKey: NSProgressTaskRootLockKey)
        adoptChild(progress, orphaned: orphaned, pendingUnitCount: 1)
    }

}

extension TaskType {

    private func withRootProgress(@noescape body: NSProgress -> Void) -> NSProgress {
        if let lock = progress.userInfo[NSProgressTaskRootLockKey] as? NSLock {
            lock.lock()
            defer { lock.unlock() }

            body(progress)
            return progress
        } else {
            let progress = NSProgress(taskRootFor: self.progress, orphaned: false)

            body(progress)
            return progress
        }
    }

    /// Extend the progress of `self` to reflect an added operation of `cost`.
    func extendingTask<Return>(unitCount cost: Int64, body: (Value) -> Return) -> (NSProgress, (Value) -> Return) {
        let progress = withRootProgress { $0.totalUnitCount += cost }

        return (progress, { [weak progress] (result) -> Return in
            progress?.becomeCurrentWithPendingUnitCount(cost)
            defer { progress?.resignCurrent() }
            return body(result)
        })
    }

}