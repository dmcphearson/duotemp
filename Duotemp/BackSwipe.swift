import UIKit

/// Keeps the edge swipe back working on screens that replace the system back button. The location pager's
/// own horizontal paging waits for the edge swipe to fail, so a swipe from the left edge always goes back.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer
    }
}
