// DNDManagerTests.swift
// OpenShotTests
//
// Regression test for the DND-warning data race: concurrent callers must
// see exactly one `fireOnce()` succeed, deterministically, without relying
// on Process/Shortcuts CLI or ToastManager.

import Testing
@testable import OpenShot

@Suite("OnceGate Tests")
struct OnceGateTests {

    @Test("Only the first of many concurrent callers fires")
    func testOnlyFiresOnce() async {
        let gate = OnceGate()
        let successCount = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    gate.fireOnce()
                }
            }
            var successes = 0
            for await result in group where result {
                successes += 1
            }
            return successes
        }
        #expect(successCount == 1)
    }

    @Test("A fresh gate fires on the first call and not after")
    func testSequentialCalls() {
        let gate = OnceGate()
        #expect(gate.fireOnce() == true)
        #expect(gate.fireOnce() == false)
        #expect(gate.fireOnce() == false)
    }
}
