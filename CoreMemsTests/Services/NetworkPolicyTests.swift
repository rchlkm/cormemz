// CoreMemsTests/Services/NetworkPolicyTests.swift
import Testing

@testable import CoreMems

@Suite("Network policy")
struct NetworkPolicyTests {
  private let wifi = NetworkConditions(isConnected: true, isExpensive: false, isConstrained: false)
  private let cellular = NetworkConditions(
    isConnected: true, isExpensive: true, isConstrained: false)
  private let lowDataWifi = NetworkConditions(
    isConnected: true, isExpensive: false, isConstrained: true)
  private let offline = NetworkConditions(
    isConnected: false, isExpensive: false, isConstrained: false)

  @Test func wifiAndCellularDownloadsOnAnyConnection() {
    #expect(NetworkPolicy.wifiAndCellular.allowsDownloads(on: wifi))
    #expect(NetworkPolicy.wifiAndCellular.allowsDownloads(on: cellular))
  }

  @Test func wifiOnlyRefusesCellular() {
    #expect(NetworkPolicy.wifiOnly.allowsDownloads(on: wifi))
    #expect(!NetworkPolicy.wifiOnly.allowsDownloads(on: cellular))
  }

  @Test func downloadedOnlyNeverDownloads() {
    #expect(!NetworkPolicy.downloadedOnly.allowsDownloads(on: wifi))
    #expect(!NetworkPolicy.downloadedOnly.allowsDownloads(on: cellular))
  }

  @Test(arguments: NetworkPolicy.allCases)
  func offlineNeverDownloads(policy: NetworkPolicy) {
    #expect(!policy.allowsDownloads(on: offline))
  }

  @Test(arguments: NetworkPolicy.allCases)
  func lowDataModeNeverDownloads(policy: NetworkPolicy) {
    #expect(!policy.allowsDownloads(on: lowDataWifi))
  }
}
