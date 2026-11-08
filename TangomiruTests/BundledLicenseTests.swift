import Testing
@testable import Tangomiru

struct BundledLicenseTests {
    @Test(arguments: BundledLicense.all)
    func licenseTextIsBundled(_ license: BundledLicense) throws {
        let text = try #require(license.text)
        #expect(!text.isEmpty)
    }

    @Test func plamoLicenseIsIncluded() throws {
        let text = try #require(BundledLicense.all.first?.text)
        #expect(text.hasPrefix("PLaMoコミュニティライセンス契約"))
    }
}
