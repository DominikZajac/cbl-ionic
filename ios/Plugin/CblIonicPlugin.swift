import Foundation
import Capacitor
import CouchbaseLiteSwift
import CbliteSwiftJsLib

@objc(CblIonicPlugin)
public class CblIonicPluginPlugin: CAPPlugin {
    
    // MARK: - Member Properties
    var databaseChangeListeners = [String: Any]()
    
    var collectionChangeListeners = [String: Any]()
    var collectionDocumentChangeListeners = [String: Any]()
    var queryChangeListeners = [String: Any]()
    
    var replicatorChangeListeners = [String: Any]()
    var replicatorDocumentListeners = [String: Any]()
    
    var queryCount: Int = 0
    var replicatorCount: Int = 0
    var allResultsChunkSize: Int = 256
    
    // Create a serial DispatchQueue for background tasks
    let backgroundQueue = DispatchQueue(label: "com.cblite.ionic.backgroundQueue")
    
    override public func load() {
        
        // Change listeners
        replicatorChangeListeners = [:]
        replicatorDocumentListeners = [:]
        databaseChangeListeners = [:]
        collectionDocumentChangeListeners = [:]
        queryChangeListeners = [:]
    }
    
    // MARK: - Capacitor Plugin Functions
    
    @objc func plugin_Configure(_ call: CAPPluginCall) {
        let config = call.getObject("config", [:]) as [String: Any]
        
        if let chunkSizeVal = config["allResultsChunkSize"] as? Int {
            self.allResultsChunkSize = chunkSizeVal
        }
        call.resolve()
    }
    
    // MARK: - File System Helper Functions
    
    @objc func file_GetDefaultPath(_ call: CAPPluginCall) {
        backgroundQueue.async {
            let paths = FileSystemHelper.fileGetDefaultPath()
            DispatchQueue.main.async {
                call.resolve(["path": paths])
                return
            }
        }
    }
    
    @objc func file_GetFileNamesInDirectory(_ call: CAPPluginCall) {
        guard let directoryPath = call.getString("path") else {
            call.reject("Error:  No path provided")
            return
        }
        backgroundQueue.async {
            do {
                let files = try FileSystemHelper.fileGetFileNamesInDirectory(directoryPath)
                let result = ["files": files]
                DispatchQueue.main.async {
                    call.resolve(result)
                    return
                }
                
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - Database Functions
    
    @objc func database_Open(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                call.reject("Error:  No database name provided")
                return
            }
            guard let configValue = (call.getObject("config") as [AnyHashable: Any]?) else {
                call.reject("Error:  No database configuration provided")
                return
            }
            do {
                try DatabaseManager.shared.open (name, databaseConfig: configValue)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error opening database: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_Close(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing database name")
                }
                return
            }
            do {
                try DatabaseManager.shared.close(name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error closing database: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_Exists(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let existsName = call.getString("existsName"),
                  let directory = call.getString("directory") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing parameters")
                }
                return
            }
            let exists = DatabaseManager.shared.exists(existsName, directoryPath: directory)
            DispatchQueue.main.async {
                call.resolve(["exists": exists])
                return
            }
        }
    }
    
    @objc func database_GetPath(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing database name")
                }
                return
            }
            
            do {
                if let path = try DatabaseManager.shared.getPath(name){
                    DispatchQueue.main.async {
                        call.resolve(["path": path])
                        return
                    }
                } else {
                    DispatchQueue.main.async {
                        call.reject("Error not path found for database: \(name)")
                        return
                    }
                    
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting database path: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_Copy(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let path = call.getString("path"),
                  let name2 = call.getString("newName") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters")
                }
                return
            }
            
            guard let configValue = (call.getObject("config") as [AnyHashable: Any]?) else {
                call.reject("Error:  No database configuration provided")
                return
            }
            do {
                try DatabaseManager.shared.copy(path, newName: name2, databaseConfig: configValue)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Failed to copy database: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_Delete(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameter 'name'")
                }
                return
            }
            do {
                try DatabaseManager.shared.delete(name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to delete database: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - Database Maintenance Functions
    
    @objc func database_PerformMaintenance(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"), let maintenanceType = call.getInt("maintenanceType") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameter 'name' or 'maintenanceType'")
                }
                return
            }
            DispatchQueue.main.async {
                do {
                    if let enumValue = MaintenanceType(rawValue: UInt8(maintenanceType)) {
                        try DatabaseManager.shared.performMaintenance(name, maintenanceType: enumValue)
                        
                        call.resolve()
                        return
                    } else {
                        DispatchQueue.main.async {
                            call.reject("Unable to convert maintenance type from:  \(maintenanceType)")
                            return
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        call.reject("Unable to peform maintenance on database: \(error.localizedDescription)")
                        return
                    }
                }
            }
        }
    }
    
    // MARK: - Scope Functions
    
    @objc func scope_GetScopes(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameter 'name'")
                }
                return
            }
            do {
                if let scopes = try DatabaseManager.shared.scopes(name) {
                    let scopeNames = Array(scopes).map { scope -> [String: Any] in
                        return [
                            "name": scope.name,
                            "databaseName": name
                        ]
                    }
                    DispatchQueue.main.async{
                        call.resolve(["scopes": scopeNames])
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get scopes for database \(name)")
                        return
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get scopese: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func scope_GetDefault(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameter 'name'")
                }
                return
            }
            do {
                if let scope = try DatabaseManager.shared.defaultScope(name) {
                    let scopeName = scope.name
                    let json = ["name": scopeName,
                                "databaseName": name];
                    DispatchQueue.main.async{
                        call.resolve(json);
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get default scope for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get default scope: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func scope_GetScope(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"), let scopeName = call.getString("scopeName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name' or 'scopeName'")
                }
                return
            }
            do {
                if let scope = try DatabaseManager.shared.scope(scopeName, databaseName: name) {
                    let scopeName = scope.name
                    let json = ["name": scopeName,
                                "databaseName": name];
                    DispatchQueue.main.async{
                        call.resolve(json)
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get scope for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get default scope: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - Collection Functions
    
    @objc func collection_GetDefault(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name") else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameter 'name'")
                }
                return
            }
            do {
                if let collection = try DatabaseManager.shared.defaultCollection(name) {
                    let json = [
                        "name": collection.name,
                        "scope": [
                            "name": collection.scope.name,
                            "databaseName": name
                        ]
                    ]
                    DispatchQueue.main.async{
                        call.resolve(json)
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get default scope for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get default scope: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetCollection(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'scopeName', or 'collectionName'")
                }
                return
            }
            do {
                if let collection = try DatabaseManager.shared.collection(collectionName, scopeName: scopeName, databaseName: name) {
                    let json = [
                        "name": collection.name,
                        "scope": [
                            "name": collection.scope.name,
                            "databaseName": name
                        ]
                    ]
                    DispatchQueue.main.async {
                        call.resolve(json)
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get collection in scope \(scopeName)  for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get collection in scope \(scopeName) for database \(name): \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetCollections(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"), let scopeName = call.getString("scopeName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name' or 'scopeName'")
                }
                return
            }
            do {
                if let scopeCollections = try DatabaseManager.shared.collections(scopeName, databaseName: name) {
                    let collections = Array(scopeCollections).map { collection -> [String: Any] in
                        return [
                            "name": collection.name,
                            "scope": [
                                "name": collection.scope.name,
                                "databaseName": name
                            ]
                        ]
                    }
                    DispatchQueue.main.async {
                        call.resolve(["collections": collections])
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to get collections in scope \(scopeName) for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to get collections: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_CreateCollection(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'scopeName', or 'collectionName'")
                }
                return
            }
            do {
                if let collection = try DatabaseManager.shared.createCollection(collectionName, scopeName: scopeName, databaseName: name) {
                    let json = [
                        "name": collection.name,
                        "scope": [
                            "name": collection.scope.name,
                            "databaseName": name
                        ]
                    ]
                    DispatchQueue.main.async {
                        call.resolve(json)
                        return
                    }
                } else {
                    DispatchQueue.main.async{
                        call.reject("Unable to create collection in scope \(scopeName)  for database \(name)")
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to create collection in scope \(scopeName) for database \(name): \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_DeleteCollection(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'scopeName', or 'collectionName'")
                }
                return
            }
            do {
                try DatabaseManager.shared.deleteCollection(collectionName, scopeName: scopeName, databaseName: name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to delete collection \(collectionName) in scope \(scopeName) for database \(name): \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - Index Functions
    
    @objc func collection_CreateIndex(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let indexName = call.getString("indexName"),
                  let indexData = call.getObject("index"),
                  let indexType = indexData["type"] as? String,
                  let items = indexData["items"] as? [[Any]]
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name',  'indexName', 'scopeName', 'collectionName' or 'index'")
                }
                return
            }
            do {
                try CollectionManager.shared.createIndex(
                    indexName,
                    indexType: indexType,
                    items: items,
                    collectionName: collectionName,
                    scopeName: scopeName,
                    databaseName: name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error creating index: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_DeleteIndex(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let indexName = call.getString("indexName"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'scopeName', 'collectionName', or 'indexName'")
                }
                return
            }
            do {
                try CollectionManager.shared.deleteIndex(indexName, collectionName: collectionName, scopeName: scopeName, databaseName: name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error deleting index: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetIndexes(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'scopeName', 'collectionName'")
                }
                return
            }
            do {
                let indexes = try CollectionManager.shared.indexes(collectionName, scopeName: scopeName, databaseName: name)
                DispatchQueue.main.async {
                    call.resolve([ "indexes": indexes])
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting indexes: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - Document Functions
    
    @objc func collection_Save(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let document = call.getObject("document"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing parameters")
                }
                return
            }
            
            let docId = call.getString("id") ?? ""
            
            //deal with concurrentyControl
            let concurrencyControlValue = call.getInt("concurrencyControl")
            var concurrencyControl: ConcurrencyControl?
            if (concurrencyControlValue != nil) {
                if let uint8Value = UInt8(exactly: concurrencyControlValue!) {
                    concurrencyControl = ConcurrencyControl(rawValue: uint8Value)
                }
            }
            do {
                let (documentId, concurrencyControlResult) = try CollectionManager.shared.saveDocument(
                    docId,
                    document: document,
                    concurrencyControl: concurrencyControl,
                    collectionName: collectionName,
                    scopeName: scopeName,
                    databaseName: name)
                DispatchQueue.main.async {
                    call.resolve([
                        "_id": documentId,
                        "concurrencyControlResult": concurrencyControlResult as Any
                    ])
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Unable to save document: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetCount(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'collectionName', or 'scopeName'")
                }
                return
            }
            
            do {
                let count = try CollectionManager.shared.documentsCount(collectionName, scopeName: scopeName, databaseName: name)
                DispatchQueue.main.async {
                    call.resolve(["count": count])
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting count of documents for collection \(collectionName), scopeName \(scopeName), databaseName \(name): \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_DeleteDocument(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let docId = call.getString("docId"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName")
            else {
                DispatchQueue.main.async {
                    call.reject("Error:  Missing required parameters 'name', 'docId', 'colllectionName', or 'scopeName'")
                }
                return
            }
            
            //deal with concurrentyControl
            let concurrencyControlValue = call.getInt("concurrencyControl")
            var concurrencyControl: ConcurrencyControl?
            if (concurrencyControlValue != nil) {
                if let uint8Value = UInt8(exactly: concurrencyControlValue!) {
                    concurrencyControl = ConcurrencyControl(rawValue: uint8Value)
                }
            }
            
            do {
                
                let result = try CollectionManager.shared.deleteDocument(docId,  concurrencyControl: concurrencyControl,
                                                                         collectionName: collectionName,
                                                                         scopeName: scopeName,
                                                                         databaseName: name)
                call.resolve(["concurrencyControlResult": result as Any])
                return
            } catch {
                call.reject("Error deleting document: \(error.localizedDescription)")
                return
            }
        }
    }
    
    @objc func collection_GetDocument(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let docId = call.getString("docId") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name', 'scopeName', 'collectionName', or 'docId'")
                }
                return
            }
            do {
                guard let doc = try CollectionManager
                    .shared
                    .document(docId,
                              collectionName: collectionName,
                              scopeName: scopeName,
                              databaseName: name)
                else {
                    DispatchQueue.main.async {
                        call.resolve([:])
                    }
                    return
                }
                
                var data: [String: Any] = [:]
                let documentMap = MapHelper.documentToMap(doc)
                data["_data"] = documentMap
                data["_id"] = docId
                data["_sequence"] = doc.sequence
                DispatchQueue.main.async {
                    call.resolve(data)
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting document: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_PurgeDocument(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let docId = call.getString("docId") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name' or 'docId'")
                }
                return
            }
            do {
                try CollectionManager
                    .shared
                    .purgeDocument(docId,
                                   collectionName: collectionName,
                                   scopeName: scopeName,
                                   databaseName: name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error purging document: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetBlobContent(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let documentId = call.getString("documentId"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let key = call.getString("key") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name', 'documentId', or 'key'")
                }
                return
            }
            do {
                
                guard let blob = try CollectionManager
                    .shared
                    .getBlobContent(key,
                                    documentId: documentId,
                                    collectionName: collectionName,
                                    scopeName: scopeName,
                                    databaseName: name)
                else {
                    DispatchQueue.main.async{
                        call.resolve(["data": []])
                    }
                    return
                }
                DispatchQueue.main.async {
                    call.resolve(["data": blob])
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting document: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_SetDocumentExpiration(_
                                                call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let expiration = call.getDate("expiration"),
                  let docId = call.getString("docId") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name', 'scopeName', 'collectionName', 'expiration', or 'docId'")
                }
                return
            }
            do {
                try CollectionManager
                    .shared
                    .setDocumentExpiration(docId,
                                           expiration: expiration,
                                           collectionName: collectionName,
                                           scopeName: scopeName,
                                           databaseName: name)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error setting document expiration: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_GetDocumentExpiration(_
                                                call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let docId = call.getString("docId") else {
                DispatchQueue.main.async {
                    
                    call.reject("Error: Missing required parameters 'name', 'scopeName', 'collectionName', or 'docId'")
                }
                return
            }
            do {
                if let date = try CollectionManager
                    .shared
                    .getDocumentExpiration(docId,
                                           collectionName: collectionName,
                                           scopeName: scopeName,
                                           databaseName: name){
                    DispatchQueue.main.async {
                        call.resolve(["date": date])
                        return
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        call.resolve()
                        return
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting document expiration: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    // MARK: - SQL++ Query Functions
    
    @objc func query_Execute(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let query = call.getString("query") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name' or 'query'")
                }
                return
            }
            do {
                if let parameters = call.getObject("parameters") {
                    
                    let result = try DatabaseManager.shared.executeQuery(
                        query,
                        parameters: parameters,
                        databaseName: name)
                    call.resolve(["data": result])
                    return
                } else {
                    let result = try DatabaseManager.shared.executeQuery(query, databaseName: name)
                    call.resolve(["data": result])
                    return
                }
                
            } catch {
                DispatchQueue.main.async {
                    if let error = error as? NSError {
                        call.reject("Error in query <\(query)>: domain: <\(error.domain)>  debugDescription: <\(error.debugDescription)>")
                    } else{
                        call.reject("Error in query <\(query)>: \(error.localizedDescription)")
                    }
                    
                    return
                }
            }
            
        }
    }
    
    @objc func query_Explain(_ call: CAPPluginCall){
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let query = call.getString("query") else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameters 'name' or 'query'")
                }
                return
            }
            do {
                if let parameters = call.getObject("parameters") {
                    let result = try DatabaseManager.shared.queryExplain(
                        query,
                        parameters: parameters,
                        databaseName: name)
                    call.resolve(["data": result])
                    return
                } else {
                    let result = try DatabaseManager.shared.queryExplain(query, databaseName: name)
                    call.resolve(["data": result])
                    return
                }
                
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error getting document expiration: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    // MARK: - Replicaton Functions
    
    @objc func replicator_Create(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let config = (call.getObject("config") as [String: Any]?) else {
                DispatchQueue.main.async {
                    call.reject("Error: Missing required parameter 'config'")
                }
                return
            }
            do {
                let replicatorId = try ReplicatorManager
                    .shared
                    .replicator(config)
                DispatchQueue.main.async {
                    call.resolve(["replicatorId": replicatorId])
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error creating replicator \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func replicator_Start(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                DispatchQueue.main.async {
                    call.reject("Error: No replicatorId supplied")
                }
                return
            }
            do {
                try ReplicatorManager.shared.start(replicatorId)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error starting replicator \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func replicator_Stop(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                DispatchQueue.main.async {
                    call.reject("Error: No replicatorId supplied")
                }
                return
            }
            do {
                try ReplicatorManager.shared.stop(replicatorId)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error stopping replicator \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func replicator_ResetCheckpoint(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                DispatchQueue.main.async {
                    call.reject("Error: No replicatorId supplied")
                }
                return
            }
            do {
                try ReplicatorManager
                    .shared
                    .resetCheckpoint(replicatorId)
                DispatchQueue.main.async {
                    call.resolve()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error resetting checkpoint \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func replicator_GetStatus(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                DispatchQueue.main.async {
                    call.reject("Error: No replicatorId supplied")
                }
                return
            }
            do {
                let status = try ReplicatorManager
                    .shared
                    .getStatus(replicatorId)
                DispatchQueue.main.async {
                    call.resolve(status)
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error resetting checkpoint \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func replicator_Cleanup(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                call.reject("Error: No replicatorId supplied")
                return
            }
            DispatchQueue.main.async {
                if let replicator = ReplicatorManager.shared.getReplicator(replicatorId: replicatorId) {
                    ReplicatorManager.shared.removeReplicator(replicatorId: replicatorId)
                    
                    if let listener = self.replicatorChangeListeners[replicatorId] as? ListenerToken {
                        replicator.removeChangeListener(withToken: listener)
                        self.replicatorChangeListeners.removeValue(forKey: replicatorId)
                    }
                    
                    if let documentListener = self.replicatorDocumentListeners[replicatorId] as? ListenerToken {
                        replicator.removeChangeListener(withToken: documentListener)
                        self.replicatorDocumentListeners.removeValue(forKey: replicatorId)
                    }
                    DispatchQueue.main.async {
                        call.resolve()
                    }
                } else {
                    DispatchQueue.main.async {
                        call.reject("No such replicator")
                    }
                }
            }
        }
    }
    
    // MARK: - Change Listener Methods
    
    @objc func replicator_AddChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                DispatchQueue.main.async {
                    call.reject("Error: No replicatorId supplied")
                }
                return
            }
            
            guard let replicator = ReplicatorManager.shared.getReplicator(replicatorId: replicatorId) else {
                DispatchQueue.main.async {
                    call.reject("No such replicator")
                }
                return
            }
            
            call.keepAlive = true
            
            let listener = replicator.addChangeListener(
                withQueue: DispatchQueue.main, { change in
                let statusJson = ReplicatorHelper
                    .generateReplicatorStatusJson(change.status)
                    call.resolve(statusJson)
            })
            self.replicatorChangeListeners[replicatorId] = listener
        }
    }
    
    @objc func replicator_RemoveChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                call.reject("Error: No replicatorId supplied")
                return
            }
            guard let replicator = ReplicatorManager.shared.getReplicator(replicatorId: replicatorId) else {
                DispatchQueue.main.async {
                    call.reject("No such replicator")
                }
                return
            }
            if let listener = self.replicatorChangeListeners[replicatorId] as? ListenerToken {
                replicator.removeChangeListener(withToken: listener)
                self.replicatorChangeListeners.removeValue(forKey: replicatorId)
                DispatchQueue.main.async {
                    return call.resolve()
                }
            } else {
                DispatchQueue.main.async {
                    call.reject("No such replicator listener")
                }
                return
            }
        }
    }
    
    @objc func replicator_AddDocumentListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                call.reject("Error: No replicatorId supplied")
                return
            }
            
            guard let replicator = ReplicatorManager.shared.getReplicator(replicatorId: replicatorId) else {
                DispatchQueue.main.async {
                    call.reject("No such replicator")
                }
                return
            }
            
            call.keepAlive = true
            
            let listener = replicator.addDocumentReplicationListener(
                withQueue: DispatchQueue.main, { change in
                let statusJson = ReplicatorHelper
                    .generateReplicationJson(change.documents, isPush: change.isPush)
                    call.resolve(statusJson)
            })
            self.replicatorDocumentListeners[replicatorId] = listener
        }
    }
    
    @objc func replicator_RemoveDocumentListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let replicatorId = call.getString("replicatorId") else {
                call.reject("Error: No replicatorId supplied")
                return
            }
            DispatchQueue.main.async {
                if let replicator = ReplicatorManager.shared.getReplicator(replicatorId: replicatorId) {
                    ReplicatorManager.shared.removeReplicator(replicatorId: replicatorId)
                    
                    if let documentListener = self.replicatorDocumentListeners[replicatorId] as? ListenerToken {
                        replicator.removeChangeListener(withToken: documentListener)
                        self.replicatorDocumentListeners.removeValue(forKey: replicatorId)
                        DispatchQueue.main.async {
                            call.resolve()
                        }
                    } else {
                        DispatchQueue.main.async {
                            call.reject("No such replicator document listener")
                        }
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        call.reject("No such replicator")
                    }
                }
            }
        }
    }
    
    @objc func database_AddChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database name or token provided")
                return
            }
            guard let db = DatabaseManager.shared.getDatabase(name) else {
                DispatchQueue.main.async {
                    call.reject("No such open database")
                }
                return
             }
             
            call.keepAlive = true
            do {
                let listener = try db
                    .defaultCollection()
                    .addChangeListener(queue: DispatchQueue.main, listener: { change in
                        let docIds = change.documentIDs
                        let data: [String: Any] = ["documentIDs": docIds]
                        call.resolve(data)
                    })
                self.databaseChangeListeners[changeListenerToken] = listener
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error in adding database change listener \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_RemoveChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database name or token provided")
                return
            }
            guard let listener = self.databaseChangeListeners[changeListenerToken] as? ListenerToken else {
                DispatchQueue.main.async {
                    call.reject("No listener found for the provided token")
                }
                return
             }
             
            listener.remove()
            DispatchQueue.main.async {
                call.resolve()
            }
        }
    }
    
    @objc func collection_AddChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database 'name', 'collectionName', 'scopeName' or 'token' provided")
                return
            }
            do {
                guard let collection = try CollectionManager.shared.getCollection(collectionName, scopeName: scopeName, databaseName: name) else {
                    DispatchQueue.main.async {
                        call.reject("No such open collection")
                    }
                    return
                }
            
                call.keepAlive = true
                let listener = collection
                    .addChangeListener(queue: DispatchQueue.main, listener: { change in
                        let docIds = change.documentIDs
                        let data: [String: Any] = ["documentIDs": docIds]
                        call.resolve(data)
                    })
                self.collectionChangeListeners[changeListenerToken] = listener
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error setting collection listener \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_RemoveChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database name or token provided")
                return
            }
            guard let listener = self.collectionChangeListeners[changeListenerToken] as? ListenerToken else {
                DispatchQueue.main.async {
                    call.reject("No listener found for the provided token")
                }
                return
            }
            
            listener.remove()
            DispatchQueue.main.async {
                call.resolve()
            }
        }
    }
    
    @objc func collection_AddDocumentChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let documentId = call.getString("documentId"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database 'name', 'collectionName', 'scopeName', 'documentId' or 'token' provided")
                return
            }
            do {
                guard let collection = try CollectionManager.shared.getCollection(collectionName, scopeName: scopeName, databaseName: name) else {
                    DispatchQueue.main.async {
                        call.reject("No such open collection")
                    }
                    return
                }
                
                call.keepAlive = true
                let listener = collection
                    .addDocumentChangeListener(id: documentId, queue: DispatchQueue.main, listener: { change in
                        let docId = change.documentID
                        let data:[String: Any] = [
                            "documentId": docId,
                            "collectionName": change.collection.name,
                            "scopeName": change.collection.scope.name,
                            "databaseName": name]
                        call.resolve(data)
                    })
                self.collectionChangeListeners[changeListenerToken] = listener
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error setting collection listener \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func collection_RemoveDocumentChangeListener(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let scopeName = call.getString("scopeName"),
                  let collectionName = call.getString("collectionName"),
                  let changeListenerToken = call.getString("changeListenerToken") else {
                call.reject("No database name or token provided")
                return
            }
            guard let listener = self.collectionDocumentChangeListeners[changeListenerToken] as? ListenerToken else {
                DispatchQueue.main.async {
                    call.reject("No listener found for the provided token")
                }
                return
            }
            
            listener.remove()
            DispatchQueue.main.async {
                call.resolve()
            }
        }
    }
    
    // MARK: - Logging Functions
    
    @objc func database_SetLogLevel(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let domainValue = call.getString("domain"),
            let logLevelValue = call.getInt("logLevel") else {
                DispatchQueue.main.async {
                    call.reject("Invalid domain or log level")
                }
                 return
             }
            do {
                try LoggingManager.shared.setLogLevel(domainValue, logLevel: logLevelValue)
                DispatchQueue.main.async {
                    call.resolve()
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error setting console logging \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    @objc func database_SetFileLoggingConfig(_ call: CAPPluginCall) {
        backgroundQueue.async {
            guard let name = call.getString("name"),
                  let config = call.getObject("config")
            else {
                call.reject("Invalid parameters")
                return
            }
             do {
                 try LoggingManager.shared.setFileLogging(name, config: config)
                 DispatchQueue.main.async {
                     call.resolve()
                 }
             } catch {
                 DispatchQueue.main.async {
                     call.reject("Error setting file logging configuration")
                 }
             }
        }
    }
}
