#if os(macOS)

import AppKit
import SwiftUI

/**
 A specialized `NSView` that reports when it has been attached/detached from the `Window`.
 Useful because being attached to the Window means that the view is also fully attached to its parent,
 and that the `ScrollView` we would like to monitor is online and is our sibling.
 */
private final class WindowAttachedReportingView : NSView {
  /**
   Called with the current window attachment state whenever changes are detected.
   */
  var onWindowAttachmentChanged: ((Bool) -> Void)? = nil
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    
    onWindowAttachmentChanged?(window != nil)
  }
}

/**
 A specialized `AppKit` bridge view that renders a `WindowAttachedReportingView`.
 When that view signals that it has been attached to the `Window` we will attempt to find a sibling `ScrollView`
 and attach our `Coordinator` to various `NSScrollView` events.
 */
struct ScrollViewFeedbackIntegrationView : NSViewRepresentable {
  // Two way binding for reading/writing the current scroll offset.
  @Binding var scrollOffset: CGPoint
  
  // Two way binding for the marker of whether there is an active scroll operation.
  @Binding var isScrolling: Bool
  
  // Two way binding for cancelling the scrolling operation.
  @Binding var cancelScrollingTrigger: Bool
  
  /**
   Called to set the current scroll offset on the main thread.
   */
  fileprivate func setScrollOffset(_ newScrollOffset: CGPoint) {
    Task { @MainActor in
      scrollOffset = newScrollOffset
    }
  }
  
  /**
   Called to set the `isScrolling` state on the main thread.
   */
  fileprivate func setIsScrolling(_ newIsScrolling: Bool) {
    Task { @MainActor in
      isScrolling = newIsScrolling
    }
  }
  
  /**
   Called to reset the indicator of stopping the current scroll operation.
   */
  fileprivate func clearCancelScrollingTrigger() {
    Task { @MainActor in
      cancelScrollingTrigger = false
    }
  }
  
  /**
   Called by the underlying implementation to create a fresh `Coordinator` for the representable view.
   */
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  /**
   Called to create the underlying `AppKit` view, given the current `Context`.
   */
  func makeNSView(context: Context) -> NSView {
    let view = WindowAttachedReportingView(frame: .zero)
    
    // Whenever the underlying NSView is attached to a window, search for a sibling ScrollView.
    // NOTE: We begin the sibling search not from the window attachment reporting view itself
    //       but from its sibling. That is because the attachment view is contained within a
    //       NSViewRepresentable adaptor.
    view.onWindowAttachmentChanged = { isAttached in
      if isAttached {
        attachToScrollViewSibling(of: view.superview, using: context.coordinator)
      }
    }
    
    return view
  }
  
  /**
   Called whenever we update (@State or other cause).
   Detects whether scroll cancellation has been requested and performs the cancellation action if needed.
   */
  func updateNSView(_ nsView: NSView, context: Context) {
    if cancelScrollingTrigger {
      context.coordinator.cancelScrolling()
      
      clearCancelScrollingTrigger()
    }
  }
  
  /**
   Called when the view is destroyed, to clean up the `Coordinator` and its state.
   */
  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    // Ensure that we reverse the attachment operation when the view goes offline.
    coordinator.detach()
  }
  
  /**
   Searches for siblings of the given `NSView` that are of type `NSScrollView`.
   If one is found, we attach our coordinator to it in order to receive scrolling feedback.
   */
  private func attachToScrollViewSibling(of nsView: NSView?, using coordinator: Coordinator) {
    // Grab subviews of the view's parent, if the parent is nil, or no subviews exist, abort.
    guard let subviews = nsView?.superview?.subviews else {
      return
    }
    
    // Find the first subview that is a NSScrollView.
    let candidate = subviews.reduce(nil) { (found: NSScrollView?, candidate: NSView) in
      if let found = found {
        return found
      }
      
      return candidate as? NSScrollView
    }
    
    // If no NSScrollView sibling is found, abort.
    guard let scrollView = candidate else {
      return
    }
    
    // Otherwise, attach our coordinator as the scroll view's delegate.
    coordinator.attach(to: scrollView)
  }
  
  /**
   The `Coordinator` object for the `AppKit` -> `SwiftUI` integration for monitoring `NSScrollView` state.
   */
  final class Coordinator : NSObject {
    // Reference to the parent integration view, cleared when `detach` is called.
    private let parent: ScrollViewFeedbackIntegrationView
    
    // Holds a reference to the scroll view we attached to so that we can undo the operation.
    private weak var scrollView: NSScrollView?
    
    /**
     Creates a new `Coordinator` from a parent `ScrollViewFeedbackIntegrationView`.
     */
    init(_ parent: ScrollViewFeedbackIntegrationView) {
      self.parent = parent
    }
    
    /**
     Attaches this instance as an observer to some notifications of an `NSScrollView`.
     */
    func attach(to scrollView: NSScrollView) {
      // Detach the previous observers first, in case we are doing this more than once
      detach()
      
      // Mark the scroll view as attached.
      self.scrollView = scrollView
      
      // Observe scroll start/end as well as live scroll notifications (bounds change).
      NotificationCenter.default.addObserver(
        forName: NSScrollView.willStartLiveScrollNotification,
        object: scrollView,
        queue: .main,
        using: self.onScrollViewWillStartScroll
      )
      
      NotificationCenter.default.addObserver(
        forName: NSScrollView.didEndLiveScrollNotification,
        object: scrollView,
        queue: .main,
        using: self.onScrollViewDidEndScroll
      )
      
      NotificationCenter.default.addObserver(
        forName: NSScrollView.didLiveScrollNotification,
        object: scrollView,
        queue: .main,
        using: self.onScrollViewScrolled
      )
    }
    
    /**
     Undoes the attach operation by detaching the coordinator from receiving scroll notifications and clearing any tracking variables in
     this instance.
     */
    func detach() {
      // Make sure we are actually attached before we remove ourself as an observer for various
      // notifications.
      guard let scrollView = scrollView else {
        return
      }
      
      // Detach notification observers.
      NotificationCenter.default.removeObserver(
        self,
        name: NSScrollView.willStartLiveScrollNotification,
        object: scrollView
      )
      
      NotificationCenter.default.removeObserver(
        self,
        name: NSScrollView.didEndLiveScrollNotification,
        object: scrollView
      )
      
      NotificationCenter.default.removeObserver(
        self,
        name: NSScrollView.didLiveScrollNotification,
        object: scrollView
      )
      
      // Clear references.
      self.scrollView = nil
    }
    
    /**
     Cancels any ongoing scroll operation by setting the content to the current one and
     forcing the scroll view to remove any animation tracking.
     */
    func cancelScrolling() {
      // TODO: Currently there doesn't seem to be any way to cancel scrolling of an NSScrollView.
    }
    
    /**
     Called when the scroll view start scrolling.
     */
    private func onScrollViewWillStartScroll(_ notification: Notification) {
      guard scrollView != nil else {
        return
      }
      
      if !parent.isScrolling {
        parent.setIsScrolling(true)
      }
    }
    
    /**
     Called when the scroll view ends scrolling.
     */
    private func onScrollViewDidEndScroll(_ notification: Notification) {
      guard scrollView != nil else {
        return
      }
      
      if parent.isScrolling {
        parent.setIsScrolling(false)
      }
    }
    
    /**
     Called when the scroll view's clip view bounds have changed (scroll offset has changed).
     */
    private func onScrollViewScrolled(_ notification: Notification) {
      guard let scrollView = scrollView else {
        return
      }
      
      if !parent.isScrolling {
        parent.setIsScrolling(true)
      }
      
      let nextOffset: CGPoint = scrollView.contentView.bounds.origin
      if parent.scrollOffset != nextOffset {
        parent.setScrollOffset(nextOffset)
      }
    }
  }
}

#endif
