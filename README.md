# SwiftUIScroll Library

[![GitHub](https://img.shields.io/github/license/xiiagency/SwiftUIScroll?style=for-the-badge)](./LICENSE)

An open source library that provides extensions to SwiftUI libraries that help with scroll views.

Developed as re-usable components for various projects at
[XII's](https://github.com/xiiagency) iOS, macOS, and watchOS applications.

## Installation

### Swift Package Manager

1. In Xcode, select File > Swift Packages > Add Package Dependency.
2. Follow the prompts using the URL for this repository
3. Select the `SwiftUIScroll` library to add to your project

## Dependencies

- [xiiagency/SwiftFoundationExtensions](https://github.com/xiiagency/SwiftFoundationExtensions)
- [xiiagency/SwiftUIExtensions](https://github.com/xiiagency/SwiftUIExtensions)

## License

See the [LICENSE](LICENSE) file.

## An expanded `ScrollViewState` ([Source](Sources/SwiftUIScroll/ScrollViewWithFeedback.swift))

```Swift
struct ScrollViewState {
  let proxy: ScrollViewProxy

  let scrollOffset: CGPoint

  let isScrolling: Bool

  let cancelScrolling: () -> Void
}
```

Represents the current state of a `ScrollView`, including:

- a reference to its `ScrollViewProxy`
- its current offset as a `CGPoint` (from the upper/left corner)
- whether the `ScrollView` is actively scrolling, including deceleration
- a reference to a function that when invoked will cancel the current scroll operation

## Receiving a `ScrollViewState` ([Source](Sources/SwiftUIScroll/ScrollViewWithFeedback.swift))

```Swift
struct ScrollViewWithFeedback<Content : View> : View {
  init(
    _ axes: Axis.Set = .vertical,
    showsIndicators: Bool = true,
    @ViewBuilder contentBuilder: @escaping (ScrollViewState) -> Content
  )

  var body: some View { get }
}
```

A view similar to `ScrollViewReader` providing not only the `ScrollViewProxy` but also the scroll view's current offset and scrolling state. Unlike `ScrollViewReader`, this view acts as a `ScrollView` itself with the content being rendered as the scroll view content.

### Example Usage

```Swift
struct FooView : View {
  var body : some View {
    ScrollViewWithFeedback { state in
      ForEach(0...100, id: \.self) { index in
        Text("Item: \(index)")
      }
      .onChange(of: state.scrollOffset) { position in
        print("OFFSET: \(position)")
      }
    }
  }
}
```

## `FeatheredScrollView` ([Source](Sources/SwiftUIScroll/FeatheredScrollView.swift))

```Swift
struct FeatheredScrollView<Content : View> : View {
  init(
    maxFeatheredPercent: CGFloat = 0.05,
    @ViewBuilder content: @escaping (ScrollViewState) -> Content
  )

  var body: some View { get }
}
```

A specialized `ScrollView` that applies a feathered mask to its content as the user begins to scroll upwards. The maximum amount of feathering is limited to requested % of the view's height (defaults at 5%).
