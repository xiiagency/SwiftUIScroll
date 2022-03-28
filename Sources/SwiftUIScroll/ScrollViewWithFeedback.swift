import SwiftUIExtensions
import SwiftUI

/**
 Represents the current state of a `ScrollView`.
 */
public struct ScrollViewState {
  /**
   The `ScrollViewProxy` for the `ScrollView`.
   Allows for scrolling to a specific child view.
   */
  public let proxy: ScrollViewProxy
  
  /**
   The current scroll offset of the `ScrollView`, in both dimensions.
   */
  public let scrollOffset: CGPoint
  
  /**
   True if the `ScrollView` is currently in the middle of a scroll operation.
   This can be the user dragging the view or the view decelerating from a scroll operation.
   */
  public let isScrolling: Bool
  
  /**
   If called, the scroll view will cancel any ongoing scrolling and stop at the current scroll offset.
   */
  public let cancelScrolling: () -> Void
}

/**
 A view similar to `ScrollViewReader` providing not only the `ScrollViewProxy` but also the scroll view's
 current offset and scrolling state. Unlike `ScrollViewReader`, this view acts as a `ScrollView` itself with the content being
 rendered as the scroll view content.
 */
public struct ScrollViewWithFeedback<Content : View> : View {
  // The set of axis for the underlying ScrollView.
  private let axes: Axis.Set
  
  // If true, scrolling indicators will be shown while a scroll operation is active.
  private let showIndicators: Bool
  
  // Callback to generate the contents of the Scrollview, given the current ScrollViewState.
  private let contentBuilder: (ScrollViewState) -> Content
  
  // The current scrolling offset of the scroll view.
  @State private var scrollOffset: CGPoint = CGPoint()
  
  // The current scrolling state.
  @State private var isScrolling: Bool = false
  
  // Marker to tell the integration view that scrolling should be cancelled.
  // Automatically reset when the operation is done.
  @State private var cancelScrollingTrigger: Bool = false
  
  /**
   Creates a new `ScrollView` with state feedback.
   
   - Parameter axes: The scroll view's scrollable axis. The default axis is the vertical axis.
   - Parameter showsIndicators: A `Bool` value that indicates whether the scroll view displays the scrollable component
                                of the content offset, in a way  suitable for the platform.
                                The default value for this parameter is  `true`.
   - Parameter content: The view builder that creates the scrollable view. Should be able to receive the current state of the view.
   */
  public init(
    _ axes: Axis.Set = .vertical,
    showsIndicators: Bool = true,
    @ViewBuilder contentBuilder: @escaping (ScrollViewState) -> Content
  ) {
    self.axes = axes
    self.showIndicators = showsIndicators
    self.contentBuilder = contentBuilder
  }
  
  public var body: some View {
    ScrollViewReader { proxy in
      // Make sure `ScrollViewFeedbackIntegrationView` below does not add any extra space
      // by wrapping in a no-space VStack.
      VStack(spacing: 0) {
        // Renders the scroll view itself with the content embedded in it.
        // The content builder closure will receive the latest known values to create the current
        // state of the scroll view.
        ScrollView(axes, showsIndicators: showIndicators) {
          contentBuilder(
            ScrollViewState(
              proxy: proxy,
              scrollOffset: scrollOffset,
              isScrolling: isScrolling,
              cancelScrolling: { cancelScrollingTrigger = true }
            )
          )
        }
        .stretch(.All)

        // We place a specialized integration view as a sibling of the above ScrollView that will
        // attach itself as a UIScrollViewDelegate in order to be able to detect changes in the
        // view's state.
        ScrollViewFeedbackIntegrationView(
          scrollOffset: $scrollOffset,
          isScrolling: $isScrolling,
          cancelScrollingTrigger: $cancelScrollingTrigger
        )
        .frame(width: 0, height: 0)
      }
    }
  }
}
