//
//  func.swift
//  CarPlayKids
//
//  Created by Developer on 22.05.2025.
//


//
//  SongEntity+CoreDataProperties.swift
//  CarPlayMusic
//
//  Created by System on 22/05/25.
//

import Foundation
import CoreData

extension SongEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongEntity> {
        return NSFetchRequest<SongEntity>(entityName: "SongEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var author: String?
    @NSManaged public var fileName: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var dateAdded: Date?

}