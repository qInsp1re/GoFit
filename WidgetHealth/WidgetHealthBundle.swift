//
//  WidgetHealthBundle.swift
//  WidgetHealth
//
//  Created by Matvey on 03.11.2023.
//

import WidgetKit
import SwiftUI

@main
struct HealthWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WidgetHealth()
    }
}
