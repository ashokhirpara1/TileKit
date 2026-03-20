import SwiftUI

struct GridEditorView: View {
    @Binding var layout: GridLayout

    @State private var editingName = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Layout name
            HStack {
                if editingName {
                    TextField("Name", text: $layout.name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { editingName = false }
                } else {
                    Text(layout.name)
                        .font(.headline)
                        .onTapGesture { editingName = true }
                }
            }

            // Visual preview
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)

                GeometryReader { geo in
                    ForEach(layout.zones) { zone in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            )
                            .overlay(
                                Text(zone.name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            )
                            .frame(
                                width: geo.size.width * zone.rect.width - 2,
                                height: geo.size.height * zone.rect.height - 2
                            )
                            .offset(
                                x: geo.size.width * zone.rect.x + 1,
                                y: geo.size.height * zone.rect.y + 1
                            )
                    }
                }
            }
            .frame(height: 120)
            .padding(.bottom, 4)

            // Quick presets
            HStack {
                Text("Presets:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("2 Col") { applyColumns(2) }
                Button("3 Col") { applyColumns(3) }
                Button("4 Col") { applyColumns(4) }
                Button("5 Col") { applyColumns(5) }
                Button("2x2") { applyGrid(2, 2) }

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // Zone list
            List {
                ForEach($layout.zones) { $zone in
                    HStack {
                        TextField("Name", text: $zone.name)
                            .frame(width: 100)

                        Text("x:\(zone.rect.x, specifier: "%.2f") y:\(zone.rect.y, specifier: "%.2f") w:\(zone.rect.width, specifier: "%.2f") h:\(zone.rect.height, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(role: .destructive) {
                            layout.zones.removeAll { $0.id == zone.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Button("Add Zone") {
                    layout.zones.append(LayoutZone(name: "New Zone", rect: .leftHalf))
                }
                Spacer()
            }
        }
        .padding()
    }

    private func applyColumns(_ count: Int) {
        let w = 1.0 / CGFloat(count)
        layout.zones = (0..<count).map { i in
            let name: String
            switch (count, i) {
            case (_, 0): name = "Left"
            case (_, let n) where n == count - 1: name = "Right"
            default: name = "Col \(i + 1)"
            }
            return LayoutZone(name: name, rect: UnitRect(x: w * CGFloat(i), y: 0, width: w, height: 1))
        }
    }

    private func applyGrid(_ cols: Int, _ rows: Int) {
        let w = 1.0 / CGFloat(cols)
        let h = 1.0 / CGFloat(rows)
        layout.zones = (0..<rows).flatMap { row in
            (0..<cols).map { col in
                let pos = row == 0 ? "Top" : "Bottom"
                let side = col == 0 ? "Left" : "Right"
                return LayoutZone(
                    name: "\(pos) \(side)",
                    rect: UnitRect(x: w * CGFloat(col), y: h * CGFloat(row), width: w, height: h)
                )
            }
        }
    }
}
