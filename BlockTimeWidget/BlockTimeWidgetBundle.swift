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
    }
}

struct BlockTimeWidget: Widget {
    let kind = "BlockTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextFlightProvider()) { entry in
            NextFlightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Flight")
        .description("Shows your next scheduled flight and time to departure.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
