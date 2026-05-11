//
//  BlockTimeWidgetBundle.swift
//  BlockTimeWidget
//

import WidgetKit
import SwiftUI

@main
struct BlockTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BlockTimeWidget()
        AddFlightWidget()
    }
}

struct BlockTimeWidget: Widget {
    let kind = "BlockTimeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NextFlightIntent.self, provider: NextFlightProvider()) { entry in
            NextFlightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Flight")
        .description("Shows your next scheduled flight and all flights for the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
