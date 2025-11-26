//
//  Entity+Extension.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/8.
//

import RealityKit

extension Entity {
    
    /// Print the child element information of the current Entity and traverse recursively
    /// - Parameter level: Recursion level, used for indentation display
    func printHierarchyDetails(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        
        // Print basic information of the current Entity
        print("\(indent)Entity: '\(self.name)' (\(type(of: self))),Children count: \(self.children.count)")
        // Print component information of child elements
        if !components.isEmpty {
            print("\(indent)    Components: \(components.count)")
            for component in components {
                print("\(indent)      - \(type(of: component))")
            }
        }
       
        // If there are child elements, iterate and print information of each child element
        if !self.children.isEmpty {
            print("\(indent)Children details:")
            
            for (index, child) in self.children.enumerated() {
                let childIndent = String(repeating: "  ", count: level + 1)
                
                // Recursively process child elements of the child element
                print("\(childIndent)    Recursive children:")
                child.printHierarchyDetails(level: level + 2)
                
                // Add separator line between each child element
                if index < self.children.count - 1 {
                    print("\(childIndent)---")
                }
            }
        } else {
            print("\(indent)No children found")
        }
    }
    
    /// Simplified version: Print only the hierarchical structure of names and types
    /// - Parameter level: Recursion level, used for indentation display
    func printHierarchy(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)\(self.name.isEmpty ? "<unnamed>" : self.name) (\(type(of: self)))")
        
        for child in self.children {
            child.printHierarchy(level: level + 1)
        }
    }
    
    // MARK: - Component Search Methods
    
    /// Find the first Entity containing a specific Component type using depth-first search
    /// - Parameter componentType: The component type to search for
    /// - Returns: The first Entity containing the specified component, or nil if not found
    func findFirstEntity<T: Component>(with componentType: T.Type) -> Entity? {
        // First check if the current Entity contains the specified component
        if self.components.has(componentType) {
            return self
        }
        
        // Depth-first search child elements
        for child in self.children {
            if let found = child.findFirstEntity(with: componentType) {
                return found
            }
        }
        
        return nil
    }
    
    /// Find all Entities containing a specific Component type using depth-first search
    /// - Parameter componentType: The component type to search for
    /// - Returns: An array of all Entities containing the specified component
    func findAllEntities<T: Component>(with componentType: T.Type) -> [Entity] {
        var results: [Entity] = []
        
        // Check if the current Entity contains the specified component
        if self.components.has(componentType) {
            results.append(self)
        }
        
        // Depth-first search child elements
        for child in self.children {
            results.append(contentsOf: child.findAllEntities(with: componentType))
        }
        
        return results
    }
    
    
}
