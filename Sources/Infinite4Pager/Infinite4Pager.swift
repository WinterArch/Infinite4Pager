//
//  Infinite4Pager.swift
//  Infinite4Pager
//
//  Created by Yang Xu on 2024/7/8.
//

import SwiftUI

struct Infinite4Pager<V: View>: View {
    @State private var axis: Axis?
    @State private var size: CGSize = .zero
    @State private var currentHorizontalPage: Int = 0
    @State private var currentVerticalPage: Int = 0
    
    /// 横向总视图数量，nil 为无限
    var totalHorizontalPage: Int? = 3 // = nil
    /// 纵向总视图数量，nil 为无限
    var totalVerticalPage: Int? = 3 // = nil
    /// 横向翻页位移阈值，松开手指后，预测距离超过容器宽度的百分比，超过即翻页
    var horizontalThresholdRatio: CGFloat = 1/3
    /// 纵向翻页位移阈值，松开手指后，预测距离超过容器高度的百分比，超过即翻页
    var verticalThresholdRatio: CGFloat = 1/4
    
    @ViewBuilder
    let getPage: (_ offsetGridX: Int, _ offsetGridY: Int) -> V
    
    var body: some View {
        Color.clear
            .overlay(alignment: .center) {
                Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Group {
                            Color.clear
                            // top
                            getAdjacentPage(direction: .vertical, offset: -1).environment(\.pageType, .top)
                            Color.clear
                        }
                        .frame(width: size.width, height: size.height)
                    }
                    GridRow {
                        Group {
                            getAdjacentPage(direction: .horizontal, offset: -1).environment(\.pageType, .leading)
                            getPage(currentHorizontalPage, currentVerticalPage).environment(\.pageType, .current)
                            getAdjacentPage(direction: .horizontal, offset: 1).environment(\.pageType, .trailing)
                        }
                        .frame(width: size.width, height: size.height)
                    }
                    GridRow {
                        Group {
                            Color.clear
                            // top
                            getAdjacentPage(direction: .vertical, offset: -1).environment(\.pageType, .bottom)
                            Color.clear
                        }
                        .frame(width: size.width, height: size.height)
                    }
                }
            }
            .contentShape(Rectangle())
            .id("\(currentHorizontalPage),\(currentVerticalPage)")
            .modifier(
                PagerTotalModifier(
                    axis: $axis,
                    size: $size,
                    currentHorizontalPage: $currentHorizontalPage,
                    currentVerticalPage: $currentVerticalPage,
                    totalHorizontalPage: totalHorizontalPage,
                    totalVerticalPage: totalVerticalPage,
                    horizontalThresholdRatio: horizontalThresholdRatio,
                    verticalThresholdRatio: verticalThresholdRatio
                )
            )
            .modifier(Infinite4Pager.SizeCalculator(value: $size))
    }
    
    private func getAdjacentPage(direction: Axis?, offset: Int) -> some View {
        let nextPage: Int? = switch direction {
        case .horizontal: getNextPage(currentHorizontalPage, total: totalHorizontalPage, direction: offset)
        case .vertical: getNextPage(currentVerticalPage, total: totalVerticalPage, direction: offset)
        default: nil
        }
        
        return Group {
            if let nextPage = nextPage {
                Color.clear
                    .overlay(
                        direction == .horizontal
                        ? getPage(nextPage, currentVerticalPage)
                        : getPage(currentHorizontalPage, nextPage)
                    )
            } else {
                Color.clear
            }
        }
    }
    
    private func getNextPage(_ current: Int, total: Int?, direction: Int) -> Int? {
        if let total = total {
            let next = current + direction
            return (0 ..< total).contains(next) ? next : nil
        }
        return current + direction
    }
}

extension Infinite4Pager {
    struct SizeCalculator: ViewModifier {
        @Binding var value: CGSize
        func body(content: Content) -> some View {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear.task(id: geometry.size, { value = CGSize(width: geometry.size.width/1, height: geometry.size.height/1) })
                    }
                )
        }
    }
}

extension Infinite4Pager {
    struct PagerTotalModifier: ViewModifier {
        @Binding var axis: Axis?
        @Binding var size: CGSize
        @Binding var currentHorizontalPage: Int
        @Binding var currentVerticalPage: Int
        
        /// 横向总视图数量，nil 为无限
        var totalHorizontalPage: Int? = 3 // = nil
        /// 纵向总视图数量，nil 为无限
        var totalVerticalPage: Int? = 3 // = nil
        /// 横向翻页位移阈值，松开手指后，预测距离超过容器宽度的百分比，超过即翻页
        var horizontalThresholdRatio: CGFloat = 1/3
        /// 纵向翻页位移阈值，松开手指后，预测距离超过容器高度的百分比，超过即翻页
        var verticalThresholdRatio: CGFloat = 1/4
        /// 是否启用视图可见感知
        var enablePageVisibility: Bool = false
        private let animation: Animation = .easeOut(duration: 0.22)
        private let edgeBouncyAnimation: Animation = .smooth

        @State private var offset: CGSize = .zero
        @State private var hasDragCancelled = false
        @GestureState private var isDragging = false
        func body(content: Content) -> some View {
            content
                .disabled(isDragging)
                .transformEffect(.identity)
                .offset(offset)
                .simultaneousGesture(dragGesture)
                .onChange(of: isDragging) { _ in
                    // 处理系统对拖动手势的打断
                    if !isDragging {
                        if !hasDragCancelled {
                            withAnimation(edgeBouncyAnimation) {
                                offset = .zero
                            }
                        } else {
                            hasDragCancelled = false
                        }
                    }
                }
                .onChange(of: currentVerticalPage) { _ in
                    offset = .zero
                }
                .onChange(of: currentHorizontalPage) { _ in
                    offset = .zero
                }
                .environment(\.pagerIsDragging, isDragging)
                .environment(\.pagerCurrentPage, CurrentPage(horizontal: currentHorizontalPage, vertical: currentVerticalPage))
                .transformEnvironment(\.mainPageOffsetInfo) { value in
                    if enablePageVisibility {
                        value = MainPageOffsetInfo(mainPagePercent: mainPagePercent(), direction: axis)
                    }
                }
        }
        
        private var dragGesture: some Gesture {
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    if !state { state = true }
                }
                .onChanged { value in
                    if axis == nil {
                        let tempAxis: Axis = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal
                        : .vertical
                        switch tempAxis {
                        case .horizontal:
                            if totalHorizontalPage != 0 { axis = .horizontal }
                        case .vertical:
                            if totalVerticalPage != 0 { axis = .vertical }
                        }
                    }
                    guard let axis else { return }
                    offset = switch axis {
                    case .horizontal:
                        CGSize(
                            width: boundedDragOffset(
                                value.translation.width,
                                pageSize: size.width,
                                currentPage: currentHorizontalPage,
                                totalPages: totalHorizontalPage
                            ),
                            height: 0
                        )
                    case .vertical:
                        CGSize(
                            width: 0,
                            height: boundedDragOffset(
                                value.translation.height,
                                pageSize: size.height,
                                currentPage: currentVerticalPage,
                                totalPages: totalVerticalPage
                            )
                        )
                    }
                }
                .onEnded { value in
                    let isHorizontal = axis == .horizontal
                    let pageSize = isHorizontal ? size.width : size.height
                    let currentPage = isHorizontal ? currentHorizontalPage : currentVerticalPage
                    let totalPages = isHorizontal ? totalHorizontalPage : totalVerticalPage
                    let thresholdRatio = isHorizontal ? horizontalThresholdRatio : verticalThresholdRatio
                    
                    let translation = isHorizontal ? value.predictedEndTranslation.width : value.predictedEndTranslation.height
                    let boundedTranslation = boundedDragOffset(translation, pageSize: pageSize, currentPage: currentPage, totalPages: totalPages)
                    
                    let direction = getDirection(by: translation)
                    let isAtBoundary = isAtBoundary(direction)
                    if abs(boundedTranslation) > pageSize * thresholdRatio, !isAtBoundary {
                        let newOffset = switch axis {
                        case .horizontal:
                            CGSize(width: (-direction) * pageSize,
                                   height: 0)
                        default:
                            CGSize(width: 0,
                                   height: (-direction) * pageSize)
                        }
                        withAnimation(animation) {
                            offset = newOffset
                        }
                        // TODO: 将iOS17的动画回调功能在iOS16完全实现
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.22) { // 0.22是一个和动画持续时间相同的魔法值
                            if axis == .horizontal {
                              if let total = totalHorizontalPage {
                                // 有限页面的情况
                                currentHorizontalPage = (currentHorizontalPage + (direction == 1 ? 1 : -1) + total) % total
                              } else {
                                // 无限滚动的情况
                                currentHorizontalPage += direction == 1 ? 1 : -1
                              }
                            }

                            if axis == .vertical {
                              if let total = totalVerticalPage {
                                // 有限页面的情况
                                currentVerticalPage = (currentVerticalPage + (direction == 1 ? 1 : -1) + total) % total
                              } else {
                                // 无限滚动的情况
                                currentVerticalPage += direction == 1 ? 1 : -1
                              }
                            }
                            axis = nil
                        }
                    } else {
                        withAnimation(edgeBouncyAnimation) {
                          offset = .zero
                          axis = nil
                        }
                    }
                }
        }
        
        // 根据 container size 和 offset，计算主视图的可见参考值
        // 0 = 完全可见，横向时, -1 左侧完全移出，+1 右侧完全移出
        // 纵向时， -1 向上完全移出，+1 向下完全移出
        private func mainPagePercent() -> Double {
            switch axis {
            case .horizontal:
                offset.width / size.width
            case .vertical:
                offset.height / size.height
            case .none:
                0
            }
        }

        
        private func boundedDragOffset(
            _ offset: CGFloat,
            pageSize: CGFloat,
            currentPage: Int,
            totalPages: Int?
        ) -> CGFloat {
            let maxThreshold = pageSize / 2
            
            if let total = totalPages {
                if (currentPage == 0 && offset > 0) || (currentPage == total - 1 && offset < 0) {
                    let absOffset = abs(offset)
                    let progress = min(absOffset / maxThreshold, 1.0)
                    
                    // 使用更线性的阻尼函数
                    let dampeningFactor = 1 - progress * 0.5
                    
                    let dampendOffset = absOffset * dampeningFactor
                    return offset > 0 ? dampendOffset : -dampendOffset
                }
            }
            return offset
        }
        
        // 判断是否为边界视图
        private func isAtBoundary(_ direction: CGFloat) -> Bool {
            let direction = Int(direction)
            guard let axis else { return false }
            switch axis {
            case .horizontal:
                if let total = totalHorizontalPage {
                    // 有限水平页面的情况
                    return (currentHorizontalPage == 0 && direction < 0) || (currentHorizontalPage == total - 1 && direction > 0)
                    
                } else {
                    // 无限水平滚动的情况
                    return false
                }
            case .vertical:
                if let total = totalVerticalPage {
                    // 有限垂直页面的情况
                    return (currentVerticalPage == 0 && direction < 0) ||
                    (currentVerticalPage == total - 1 && direction > 0)
                } else {
                    // 无限垂直滚动的情况
                    return false
                }
            }
        }
        private func getDirection(by translation: CGFloat) -> CGFloat {
            -translation / abs(translation)
        }
    }
}

private struct MainPageOffsetInfo: Equatable {
    let mainPagePercent: Double
    let direction: Axis?
}
private enum PageType {
    case current, leading, trailing, top, bottom
}
private struct CurrentPage: Equatable {
    let horizontal: Int
    let vertical: Int
}

private struct OffsetKey: EnvironmentKey {
    static let defaultValue: MainPageOffsetInfo? = MainPageOffsetInfo(mainPagePercent: 0, direction: .none)
}
private struct PageTypeKey: EnvironmentKey {
    static let defaultValue: PageType = .current
}
private struct CurrentPageKey: EnvironmentKey {
    static let defaultValue: CurrentPage? = nil
}
private struct IsDraggingKey: EnvironmentKey {
    static let defaultValue = false
}
fileprivate extension EnvironmentValues {
     var mainPageOffsetInfo: MainPageOffsetInfo? {
        get { self[OffsetKey.self] }
        set { self[OffsetKey.self] = newValue }
    }
    var pageType: PageType {
        get { self[PageTypeKey.self] }
        set { self[PageTypeKey.self] = newValue }
    }
    var pagerCurrentPage: CurrentPage? {
        get { self[CurrentPageKey.self] }
        set { self[CurrentPageKey.self] = newValue }
    }
    var pagerIsDragging: Bool {
        get { self[IsDraggingKey.self] }
        set { self[IsDraggingKey.self] = newValue }
    }
}

/*
/// 单值动画回调闭包封装
/// [source](https://stackoverflow.com/questions/57763709/swiftui-withanimation-completion-callback)
struct AnimatableModifierDouble<V: Equatable>: AnimatableModifier {

    var targetValue: V

    // SwiftUI gradually varies it from old value to the new value
    var animatableData: V {
        didSet {
            checkIfFinished()
        }
    }

    var completion: () -> Void

    // Re-created every time the control argument changes
    init(bindedValue: V, completion: @escaping () -> Void) {
        self.completion = completion

        // Set animatableData to the new value. But SwiftUI again directly
        // and gradually varies the value while the body
        // is being called to animate. Following line serves the purpose of
        // associating the extenal argument with the animatableData.
        self.animatableData = bindedValue
        targetValue = bindedValue
    }

    func checkIfFinished() {
        // print("Current value: \(animatableData)")
        if animatableData == targetValue {
            // if animatableData.isEqual(to: targetValue) {
            DispatchQueue.main.async {
                self.completion()
            }
        }
    }

    // Called after each gradual change in animatableData to allow the
    // modifier to animate
    func body(content: Content) -> some View {
        // content is the view on which .modifier is applied
        content
        // We don't want the system also to
        // implicitly animate default system animatons it each time we set it. It will also cancel
        // out other implicit animations now present on the content.
            .animation(nil, value: animatableData)
    }
}
*/
