//
//  PermissionSheet.swift
//  SwiftUI_PermissionExample
//
//  Created by cano on 2025/07/30.
//

import SwiftUI
import CoreLocation
import PhotosUI
import AVKit

// MARK: - パーミッションの種類（位置情報、カメラ、マイク、写真）
enum Permission: String, CaseIterable {
    case location = "Location Services"
    case camera = "Camera Access"
    case microphone = "Microphone Access"
    case photoLibrary = "Photo Library Access"
    
    /// 各パーミッションに対応するシステムアイコン
    var symbol: String {
        switch self {
        case .location: "location.fill"
        case .camera: "camera.fill"
        case .microphone: "microphone.fill"
        case .photoLibrary: "photo.stack.fill"
        }
    }

    /// 要求順序の明示的なインデックス
    var orderedIndex: Int {
        switch self {
        case .camera: 0
        case .microphone: 1
        case .photoLibrary: 2
        case .location: 3
        }
    }

    /// 現在の許可状態（nil = 未決定、true = 許可済み、false = 拒否）
    var isGranted: Bool? {
        switch self {
        case .location:
            let status = CLLocationManager().authorizationStatus
            return status == .notDetermined ? nil : status == .authorizedAlways || status == .authorizedWhenInUse
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return status == .notDetermined ? nil : status == .authorized
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return status == .notDetermined ? nil : status == .authorized
        case .photoLibrary:
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return status == .notDetermined ? nil : status == .authorized || status == .limited
        }
    }
}

// MARK: - View拡張：任意のViewに permissionSheet を組み込み可能にする
extension View {
    @ViewBuilder
    func permissionSheet(_ permissions: [Permission]) -> some View {
        self
            .modifier(PermissionSheetViewModifier(permissions: permissions))
    }
}

// MARK: - permissionSheet の中身（ViewModifierとして実装）
fileprivate struct PermissionSheetViewModifier: ViewModifier {
    init(permissions: [Permission]) {
        // インデックス順にソートし、PermissionStateに変換
        let initialStates = permissions.sorted(by: {
            $0.orderedIndex < $1.orderedIndex
        }).compactMap {
            PermissionState(id: $0)
        }
        self._states = .init(initialValue: initialStates)
    }

    // MARK: - 状態保持用プロパティ
    @State private var showSheet: Bool = false
    @State private var states: [PermissionState]
    @State private var currentIndex: Int = 0
    var locationMananger = LocationMananger()
    @Environment(\.openURL) var openURL

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                // MARK: - シートUI構成
                VStack(spacing: 20) {
                    Text("Required Permissions")
                        .font(.title)
                        .fontWeight(.bold)

                    Image(systemName: isAllGranted ? "person.badge.shield.checkmark" : "person.badge.shield.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 100, height: 100)
                        .background {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(.blue.gradient)
                        }

                    // パーミッション一覧
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(states) { state in
                            PermissionRow(state)
                                .contentShape(.rect)
                                .onTapGesture {
                                    requestPermission(state.id.orderedIndex)
                                }
                        }
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 0)

                    // アプリ開始ボタン（すべて許可されていないと押せない）
                    Button {
                        showSheet = false
                    } label: {
                        Text("Start using the App")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue.gradient, in: .capsule)
                    }
                    .disabled(!isAllGranted)
                    .opacity(isAllGranted ? 1 : 0.6)
                    .overlay(alignment: .top) {
                        // 拒否された場合は設定アプリへ誘導
                        if isThereAnyRejection {
                            Button("Go to Settings") {
                                if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(appSettingsURL)
                                }
                            }
                            .offset(y: -30)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .presentationDetents([.height(480)])
                .interactiveDismissDisabled()
            }
            // MARK: - 位置情報許可状態の変化を監視
            .onChange(of: locationMananger.status) { oldValue, newValue in
                if let status = locationMananger.status,
                   let index = states.firstIndex(where: { $0.id == .location }) {
                    
                    if status == .notDetermined {
                        showSheet = true
                        states[index].isGranted = nil
                        requestPermission(index)
                    } else if status == .denied || status == .restricted {
                        showSheet = true
                        states[index].isGranted = false
                    } else {
                        states[index].isGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
                    }
                }
            }
            // 現在の permission index が変更されたら次の要求を試行
            .onChange(of: currentIndex) { oldValue, newValue in
                guard states[newValue].isGranted == nil else { return }
                requestPermission(newValue)
            }
            // 初回表示時の処理
            .onAppear {
                showSheet = !isAllGranted
                if let firstRequestPermission = states.firstIndex(where: { $0.isGranted == nil }) {
                    currentIndex = firstRequestPermission
                    requestPermission(firstRequestPermission)
                }
            }
    }

    // MARK: - パーミッション行（チェックアイコン＋ラベル）
    @ViewBuilder
    private func PermissionRow(_ state: PermissionState) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(.gray, lineWidth: 1)

                Group {
                    if let isGranted = state.isGranted {
                        Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isGranted ? .green : .red)
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
                .font(.title3)
                .transition(.symbolEffect)
            }
            .frame(width: 22, height: 22)

            Text(state.id.rawValue)
        }
        .lineLimit(1)
    }

    // MARK: - パーミッション要求処理
    private func requestPermission(_ index: Int) {
        Task { @MainActor in
            guard index < states.count else { return }

            let permission = states[index].id

            switch permission {
            case .location:
                // 位置情報はマネージャが別で処理しているため、ここでは次に進まない
                locationMananger.requestWhenInUseAuthorization()
                return
            case .camera:
                let status = await AVCaptureDevice.requestAccess(for: .video)
                states[index].isGranted = status
            case .microphone:
                let status = await AVCaptureDevice.requestAccess(for: .audio)
                states[index].isGranted = status
            case .photoLibrary:
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                states[index].isGranted = status == .authorized || status == .limited
            }

            // 状態が変化したので再描画
            currentIndex = index + 1

            // 次の未許可がある場合のみ再帰的に次へ
            if currentIndex < states.count, states[currentIndex].isGranted == nil {
                // 少し遅延を入れるとより自然（optional）
                try? await Task.sleep(for: .milliseconds(300))
                requestPermission(currentIndex)
            }
        }
    }

    // MARK: - 補助プロパティ
    private var isAllGranted: Bool {
        states.filter({ $0.isGranted == true }).count == states.count
    }

    private var isThereAnyRejection: Bool {
        states.contains(where: { $0.isGranted == false })
    }

    // MARK: - パーミッション状態のモデル
    private struct PermissionState: Identifiable {
        var id: Permission
        var isGranted: Bool?

        init(id: Permission) {
            self.id = id
            self.isGranted = id.isGranted
        }
    }
}

// MARK: - 位置情報パーミッションの専用マネージャ
@MainActor
@Observable
fileprivate class LocationMananger: NSObject, CLLocationManagerDelegate {
    var status: CLAuthorizationStatus?
    var manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
}
