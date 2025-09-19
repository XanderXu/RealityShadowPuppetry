//
//  Entity+Extension.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/8.
//

import RealityKit

extension Entity {
    
    /// 打印当前 Entity 的子元素信息并递归遍历
    /// - Parameter level: 递归层级，用于缩进显示
    func printHierarchyDetails(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        
        // 打印当前 Entity 的基本信息
        print("\(indent)Entity: '\(self.name)' (\(type(of: self))),Children count: \(self.children.count)")
        // 打印子元素的组件信息
        if !components.isEmpty {
            print("\(indent)    Components: \(components.count)")
            for component in components {
                print("\(indent)      - \(type(of: component))")
            }
        }
       
        // 如果有子元素，遍历并打印每个子元素的信息
        if !self.children.isEmpty {
            print("\(indent)Children details:")
            
            for (index, child) in self.children.enumerated() {
                let childIndent = String(repeating: "  ", count: level + 1)
                
                // 递归处理子元素的子元素
                print("\(childIndent)    Recursive children:")
                child.printHierarchyDetails(level: level + 2)
                
                // 在每个子元素之间添加分隔线
                if index < self.children.count - 1 {
                    print("\(childIndent)---")
                }
            }
        } else {
            print("\(indent)No children found")
        }
    }
    
    /// 简化版本：仅打印名字和类型的层级结构
    /// - Parameter level: 递归层级，用于缩进显示
    func printHierarchy(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)\(self.name.isEmpty ? "<unnamed>" : self.name) (\(type(of: self)))")
        
        for child in self.children {
            child.printHierarchy(level: level + 1)
        }
    }
    
    // MARK: - Component Search Methods
    
    /// 使用深度优先搜索查找包含特定 Component 类型的第一个 Entity
    /// - Parameter componentType: 要查找的组件类型
    /// - Returns: 包含指定组件的第一个 Entity，如果未找到则返回 nil
    func findFirstEntity<T: Component>(with componentType: T.Type) -> Entity? {
        // 首先检查当前 Entity 是否包含指定组件
        if self.components.has(componentType) {
            return self
        }
        
        // 深度优先搜索子元素
        for child in self.children {
            if let found = child.findFirstEntity(with: componentType) {
                return found
            }
        }
        
        return nil
    }
    
    /// 使用深度优先搜索查找所有包含特定 Component 类型的 Entity
    /// - Parameter componentType: 要查找的组件类型
    /// - Returns: 包含指定组件的所有 Entity 数组
    func findAllEntities<T: Component>(with componentType: T.Type) -> [Entity] {
        var results: [Entity] = []
        
        // 检查当前 Entity 是否包含指定组件
        if self.components.has(componentType) {
            results.append(self)
        }
        
        // 深度优先搜索子元素
        for child in self.children {
            results.append(contentsOf: child.findAllEntities(with: componentType))
        }
        
        return results
    }
    
    
}
