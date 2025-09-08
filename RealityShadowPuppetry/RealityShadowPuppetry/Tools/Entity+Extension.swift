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
    func printChildrenInfo(level: Int = 0) {
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
                child.printChildrenInfo(level: level + 2)
                
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
}
