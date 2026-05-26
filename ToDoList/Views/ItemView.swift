//
//  ItemView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 10.08.2023.
//

import SwiftUI
import MapKit

struct ItemView: View {
    @StateObject var viewModel = ItemViewViewModel()
    @State private var isExpanded = false
    @State private var showRouteView = false
    let item: Item
    var showCheck: Bool = true

    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation

    private let colorOptions: [Color] = [
        Color.blue, Color.red, Color.green, Color.purple, Color.orange,
        Color.pink, Color.yellow, Color.indigo, Color.cyan, Color.brown
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack(alignment: .top) {
                    // Vertical colored line
                    Rectangle()
                        .fill(tagColor)
                        .frame(width: 4)
                        .cornerRadius(2)
                        .padding(.trailing, 8)

                    // Title and due date
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(isExpanded ? nil : 1)
                            .matchedGeometryEffect(id: "title", in: animation)

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            Text(Date(timeIntervalSince1970: item.dueDate).formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .matchedGeometryEffect(id: "date", in: animation)
                    }

                    Spacer()

                    VStack {
                        if showCheck {
                            Button {
                                viewModel.toggleIsDone(item: item)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.appColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appColor)
                            .padding(.top, 2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

                // Expandable details section
                if isExpanded {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 14) {

                            // Location — adults only, real value only
                            if viewModel.isAdult &&
                               !item.locationDescription.isEmpty {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Location")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)

                                        Text(item.locationDescription)
                                            .font(.system(size: 14))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            // Tag — always visible
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(tagColor)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tag")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray)

                                    Text(item.tagName)
                                        .font(.system(size: 14))
                                }
                            }

                            // Transport — adults only
                            if viewModel.isAdult {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: item.gettingThere == 0 ? "figure.walk" : "car.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Transport")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)

                                        Text(item.gettingThere == 0 ? "Walking" : "Driving")
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                        }

                        // Show Route button — adults only, real coordinates only
                        if viewModel.isAdult,
                           let lat = item.latitude, let lon = item.longitude,
                           lat != 0, lon != 0 {
                            Button {
                                showRouteView = true
                            } label: {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 16))
                                        Text("Show Route")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [tagColor.opacity(0.85), tagColor]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: tagColor.opacity(0.4), radius: 4, x: 0, y: 2)
                                    Spacer()
                                }
                                .padding(.top, 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 4)
                    .transition(
                        AnyTransition.opacity
                            .combined(with: .scale(scale: 0.95, anchor: .top))
                    )
                    .id("expandedContent-\(isExpanded)")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
        )
        .sheet(isPresented: $showRouteView) {
            RouteMapView(item: item)
        }
    }

    private var tagColor: Color {
        guard item.tagColorIndex >= 0 && item.tagColorIndex < colorOptions.count else { return .blue }
        return colorOptions[item.tagColorIndex]
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07)
    }
}
