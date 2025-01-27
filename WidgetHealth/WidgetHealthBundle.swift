
import WidgetKit
import SwiftUI

@main
struct HealthWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WidgetHealth()
    }
}
