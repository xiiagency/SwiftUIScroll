import SwiftFoundationExtensions
import SwiftUI

/**
 The default maximum percent of the view height to feather. Drives the mask's gradient stop.
 */
public let DEFAULT_MAX_FEATHERED_PERCENT: CGFloat = 0.05

/**
 A specialized `ScrollView` that applies a feathered mask to its content as the user begins to scroll upwards.
 The maximum amount of feathering is limited to requested % of the view's height (defaults at 5%).
 */
public struct FeatheredScrollView<Content : View> : View {
  // The maximum percent of the view's height to feather.
  private let maxFeatheredPercent: CGFloat
  
  // Callback that will return the content of the `ScrollView`, provided its `ScrollViewState`.
  private let content: (ScrollViewState) -> Content
  
  // The percent of the feathering mask to apply to the content, from 0.0 to 1.0.
  // This is a percent of `maxFeatheredPercent`.
  @State private var featheredPercent: Double = 0.0
  
  // Returns the current gradient mask for the current `featheredPercent` and `maxFeatheredPercent`.
  private var featherGradient: LinearGradient {
    LinearGradient.linearGradient(
      stops: [
        Gradient.Stop(color: .black.opacity(0.0), location: 0.0),
        Gradient.Stop(color: .black, location: CGFloat(featheredPercent)),
      ],
      startPoint: .top,
      endPoint: UnitPoint(x: UnitPoint.bottom.x, y: maxFeatheredPercent)
    )
  }
  
  /**
   Creates a new `FeatheredScrollView` with a specified `maxFeatheredPercent` and content.
   */
  public init(
    maxFeatheredPercent: CGFloat = DEFAULT_MAX_FEATHERED_PERCENT,
    @ViewBuilder content: @escaping (ScrollViewState) -> Content
  ) {
    self.maxFeatheredPercent = maxFeatheredPercent
    self.content = content
  }
  
  public var body: some View {
    GeometryReader { geo in
      ScrollViewWithFeedback { state in
        content(state)
          .onChange(of: state.scrollOffset) { newScrollOffset in
            // Calculate the feathered percentage.
            let scrolledFromTop = geo.frame(in: .global).minY + newScrollOffset.y
            let maxFeatherDistance = geo.size.height * maxFeatheredPercent
            let percentOfFeatherScrolled = (scrolledFromTop / maxFeatherDistance)
            
            // Adjust the percentage state, clamped to its min/max.
            let clampedPercentOfFeatherScrolled = Double(percentOfFeatherScrolled)
              .clamped(to: 0.0...1.0)
            
            if !featheredPercent.isCloseTo(clampedPercentOfFeatherScrolled) {
              Task { @MainActor [_featheredPercent] in
                _featheredPercent.wrappedValue = clampedPercentOfFeatherScrolled
              }
            }
          }
      }
      .mask(alignment: .center) {
        featherGradient
      }
    }
  }
}
