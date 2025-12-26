//
//  CenteredDisclosureStyle.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/20/25.
//

import SwiftUI

struct CenteredDisclosureStyle: DisclosureGroupStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          configuration.isExpanded.toggle()
        }
      } label: {
        HStack(alignment: .center) {
          configuration.label
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      
      if configuration.isExpanded {
        configuration.content
          .padding(.leading, 28)
      }
    }
  }
}
