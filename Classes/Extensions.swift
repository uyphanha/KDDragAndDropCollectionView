//
//  Extensions.swift
//  KDDragAndDropCollectionViews
//
//  Created by Phanha Uy on 9/11/18.
//  Copyright © 2018 Karmadust. All rights reserved.
//

import UIKit

extension CGRect: Comparable {
    
    public var area: CGFloat {
        return self.size.width * self.size.height
    }
    
    public static func <=(lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.area <= rhs.area
    }
    public static func <(lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.area < rhs.area
    }
    public static func >(lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.area > rhs.area
    }
    public static func >=(lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.area >= rhs.area
    }
}
