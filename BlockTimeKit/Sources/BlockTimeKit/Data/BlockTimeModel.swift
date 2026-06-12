import CoreData

public enum BlockTimeModel {
    public nonisolated(unsafe) static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.module.url(forResource: "FlightDataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("FlightDataModel.momd not found in BlockTimeKit bundle")
        }
        return model
    }()
}
