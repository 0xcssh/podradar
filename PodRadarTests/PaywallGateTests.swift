import XCTest
@testable import PodRadar

final class PaywallGateTests: XCTestCase {
    func testFreshStateShowsFullPrice() {
        let state = PaywallGateState()
        XCTAssertEqual(PaywallGate.variantForNewGate(state: state), .fullPrice)
    }

    func testFirstDeclineOfFullPriceDoesNotCascade() {
        let result = PaywallGate.handleDecline(of: .fullPrice, state: PaywallGateState())
        XCTAssertTrue(result.state.hasDeclinedOnce)
        XCTAssertFalse(result.state.hasSeenTrialOffer)
        XCTAssertFalse(result.showTrialImmediately)
    }

    func testNextGateAfterFirstDeclineStillShowsFullPrice() {
        let afterFirstDecline = PaywallGate.handleDecline(of: .fullPrice, state: PaywallGateState()).state
        XCTAssertEqual(PaywallGate.variantForNewGate(state: afterFirstDecline), .fullPrice)
    }

    func testSecondDeclineOfFullPriceCascadesToTrial() {
        let afterFirstDecline = PaywallGate.handleDecline(of: .fullPrice, state: PaywallGateState()).state
        let result = PaywallGate.handleDecline(of: .fullPrice, state: afterFirstDecline)
        XCTAssertTrue(result.state.hasSeenTrialOffer)
        XCTAssertTrue(result.showTrialImmediately)
    }

    func testDecliningTrialNeverCascadesFurther() {
        var state = PaywallGateState()
        state.hasDeclinedOnce = true
        state.hasSeenTrialOffer = true
        let result = PaywallGate.handleDecline(of: .trial, state: state)
        XCTAssertFalse(result.showTrialImmediately)
        XCTAssertEqual(result.state, state)
    }

    func testOnceTrialSeenEveryFutureGateShowsTrialDirectly() {
        var state = PaywallGateState()
        state.hasDeclinedOnce = true
        state.hasSeenTrialOffer = true
        XCTAssertEqual(PaywallGate.variantForNewGate(state: state), .trial)

        // Declining the trial paywall doesn't reset back to full-price.
        let afterDecline = PaywallGate.handleDecline(of: .trial, state: state).state
        XCTAssertEqual(PaywallGate.variantForNewGate(state: afterDecline), .trial)
    }
}
