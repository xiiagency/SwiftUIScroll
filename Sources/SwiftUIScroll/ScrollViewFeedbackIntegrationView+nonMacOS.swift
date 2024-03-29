#if !os(macOS)

import SwiftUI
import UIKit

/**
 A specialized `UIView` that reports when it has been attached/detached from the Window.
 Useful because being attached to the Window means that the view is also fully attached to its parent,
 and that the `ScrollView` we would like to monitor is online and is our sibling.
 */
private final class WindowAttachedReportingView : UIView {
  /**
   Called with the current window attachment state whenever changes are detected.
   */
  var onWindowAttachmentChanged: ((Bool) -> Void)? = nil
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    
    onWindowAttachmentChanged?(window != nil)
  }
}

/**
 A specialized UIKit bridge view that renders a `WindowAttachedReportingView`.
 When that view signals that it has been attached to the `Window` we will attempt to find a sibling `ScrollView`
 and attach our `Coordinator` as its `UIScrollViewDelegate`.
 */
struct ScrollViewFeedbackIntegrationView : UIViewRepresentable {
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
   Called to create the underlying `UIKit` view, given the current `Context`.
   */
  func makeUIView(context: Context) -> UIView {
    let view = WindowAttachedReportingView(frame: .zero)
    
    // Whenever the underlying UIView is attached to a window, search for a sibling ScrollView.
    // NOTE: We begin the sibling search not from the window attachment reporting view itself
    //       but from its sibling. That is because the attachment view is contained within a
    //       UIViewRepresentable adaptor.
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
  func updateUIView(_ uiView: UIView, context: Context) {
    if cancelScrollingTrigger {
      context.coordinator.cancelScrolling()
      
      clearCancelScrollingTrigger()
    }
  }
  
  /**
   Called when the view is destroyed, to clean up the `Coordinator` and its state.
   */
  static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
    // Ensure that we reverse the attachment operation when the view goes offline.
    coordinator.detach()
  }
  
  /**
   Searches for siblings & nephews of the given `UIView` that are of type `UIScrollView`.
   If one is found, we attach our coordinator as that `ScrollView`'s `UIScrollViewDelegate`
   in order to receive scrolling feedback.
   */
  private func attachToScrollViewSibling(of uiView: UIView?, using coordinator: Coordinator) {
    // Grab subviews of the view's parent, if the parent is nil, or no subviews exist, abort.
    guard let siblings = uiView?.superview?.subviews else {
      return
    }
    
    var candidate: UIScrollView? = nil
    
    /**
     NOTE: With the release of iOS 17 a wrapping
     `SwiftUI HostingScrollView PlatformContainer` was added around UIScrollViews so
     instead the candidate always being our sibling, we now need to also look at our nephews.
     */
    for sibling in siblings {
      
      // First check if the sibling is a candidate
      if let sibling = sibling as? UIScrollView {
        candidate = sibling
        break
      }
      
      // Then check if any of its children is a Scroll View
      for child in sibling.subviews {
        if let child = child as? UIScrollView {
          candidate = child
          break
        }
      }
    }
    
    // If no UIScrollView sibling or nephew is found, abort.
    guard let scrollView = candidate else {
      return
    }
    
    // Otherwise, attach our coordinator as the scroll view's delegate.
    coordinator.attach(to: scrollView)
  }
  
  /**
   The `Coordinator` object for the `UIKit` -> `SwiftUI` integration, which also acts as a `ScrollView` delegate.
   */
  final class Coordinator : NSObject, UIScrollViewDelegate {
    // Reference to the parent integration view, cleared when `detach` is called.
    private let parent: ScrollViewFeedbackIntegrationView
    
    // Holds a reference to the scroll view we attached to so that we can undo the operation.
    private weak var scrollView: UIScrollView?
    
    // Holds any UIScrollViewDelegate that was registered in the scroll view prior to us
    // attaching to receive feedback.
    private weak var wrappedDelegate: UIScrollViewDelegate?
    
    /**
     Creates a new `Coordinator` from a parent `ScrollViewFeedbackIntegrationView`.
     */
    init(_ parent: ScrollViewFeedbackIntegrationView) {
      self.parent = parent
    }
    
    /**
     Attaches this instance as the `UIScrollViewDelegate` of the given scroll view.
     If an existing delegate is already registered with the `ScrollView`,
     we will retain it and forward all notifications to that delegate as well.
     Only does this if we are not already the delegate and we do not have a previously known wrappedDelegate.
     */
    func attach(to scrollView: UIScrollView) {
      // Make sure that we aren't attaching twice.
      guard scrollView.delegate !== self && wrappedDelegate == nil else {
        return
      }
      
      // Retain the previous delegate and the scroll view itself so that we can undo the operation.
      self.scrollView = scrollView
      self.wrappedDelegate = scrollView.delegate
      
      // Set this instance as the delegate.
      scrollView.delegate = self
    }
    
    /**
     Undoes the attach operation by restoring the scroll view's previously known delegate and clearing any tracking variables in
     this instance.
     */
    func detach() {
      // Make sure we can get to the scroll view and we are still its delegate.
      guard let scrollView = scrollView, scrollView.delegate === self else {
        return
      }
      
      // Restore previous delegate.
      scrollView.delegate = wrappedDelegate
      
      // Clear references.
      self.scrollView = nil
      self.wrappedDelegate = nil
    }
    
    /**
     Cancels any ongoing scroll operation by setting the content to the current one and
     forcing the scroll view to remove any animation tracking.
     */
    func cancelScrolling() {
      guard let scrollView = scrollView else {
        return
      }
      
      scrollView.setContentOffset(scrollView.contentOffset, animated: false)
    }
    
    /**
     Called when we detect a scroll state change via one of the `UIScrollViewDelegate` callback functions.
     Responsible for reporting the change to the caller if it has actually changed.
     */
    private func onNextIsScrolling(_ nextIsScrolling: Bool) {
      if parent.isScrolling != nextIsScrolling {
        parent.setIsScrolling(nextIsScrolling)
      }
    }
    
    /**
     Called when we detect a scroll offset change via one of the `UIScrollViewDelegate` callback functions.
     Responsible for reporting the change if the new offset represents an actual change.
     */
    private func onNextScrollOffset(_ nextOffset: CGPoint) {
      if parent.scrollOffset != nextOffset {
        parent.setScrollOffset(nextOffset)
      }
    }
    
    /**
     Returns true if the current instance or the wrappedDelegate instance can respond to the given selector.
     We do this so that we don't have to implement every func of `UIScrollViewDelegate`
     in this instance but forward unimplemented ones to the wrappedDelegate (if it exists).
     */
    override func responds(to aSelector: Selector!) -> Bool {
      // If this instance has a function for this selector, we can respond to it.
      if super.responds(to: aSelector) {
        return true
      }
      
      // If we have a wrapped delegate, see if it can respond.
      if let wrapped = wrappedDelegate, wrapped.responds(to: aSelector) {
        return true
      }
      
      // Otherwise, we can't respond to this selector.
      return false
    }
    
    /**
     Returns the target that will respond to the given selector.
     It is assumed that responds(to:) is called prior to this being called. We use this function to correctly route the selector to either
     this instance or the wrappedDelegate instance, depending on who has a concrete implementation for it.
     Our instance will have precedence, meaning that if you implement a `UIScrollViewDelegate`
     function in this instance you need to make sure you also forward the call to the wrappedDelegate instance if it exists.
     */
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
      // If we have an implementation, we will be handling it via this instance.
      if super.responds(to: aSelector) {
        return self.forwardingTarget(for: aSelector)
      }
      
      // Otherwise, check if the wrapper can respond to it, handling it via the wrappedDelegate.
      if let wrapped = wrappedDelegate, wrapped.responds(to: aSelector) {
        return wrapped
      }
      
      // If we got here something went very wrong. responds(to:) should have returned false.
      fatalError("Neither current instance nor wrapped delegate responds to selector: \(aSelector.debugDescription)")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      wrappedDelegate?.scrollViewDidScroll?(scrollView)
      
      onNextScrollOffset(scrollView.contentOffset)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
      wrappedDelegate?.scrollViewWillBeginDragging?(scrollView)
      
      onNextIsScrolling(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
      wrappedDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
      
      if !decelerate {
        onNextIsScrolling(false)
      }
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
      wrappedDelegate?.scrollViewWillBeginDecelerating?(scrollView)
      
      onNextIsScrolling(true)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      wrappedDelegate?.scrollViewDidEndDecelerating?(scrollView)
      
      onNextIsScrolling(false)
    }
  }
}

#endif
