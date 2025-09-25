import Foundation
nonisolated
class ProgressWatcher: NSObject {

    enum ObservationKeyPath: String {
        case fractionCompleted
    }
    
    var progressHandler: ((Double) -> Void)?

    let progress: Progress
    private var kvoContext = 0
    private let observationQueue = DispatchQueue(label: "Bonjour.ProgressWatcher", qos: .userInteractive)

    init(progress: Progress) {
        self.progress = progress
        super.init()
        progress.addObserver(self,
                             forKeyPath: ObservationKeyPath.fractionCompleted.rawValue,
                             options: [],
                             context: &self.kvoContext)
    }
    deinit {
        self.progress.removeObserver(self,
                                     forKeyPath: "fractionCompleted", 
                                     context: &self.kvoContext)
    }
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if context == &self.kvoContext {
            switch keyPath {
            case ObservationKeyPath.fractionCompleted.rawValue:
                if let progress = object as? Progress {
                    self.observationQueue.async {[weak self] in
                        self?.progressHandler?(progress.fractionCompleted)
                    }
                }
            default: break
            }
        } else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
        }
    }
}
