import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct BackgroundDownloadHandler: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        true
    }
}
