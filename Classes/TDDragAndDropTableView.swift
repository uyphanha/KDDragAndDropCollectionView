//
//  TDDragAndDropTableView.swift
//  TDDragAndDropViews
//
//  Created by Phanha Uy on 9/11/18.
//  Copyright © 2018 Mäd. All rights reserved.
//

import UIKit

public protocol TDDragAndDropTableViewDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, indexPathForDataItem dataItem: AnyObject) -> IndexPath?
    func tableView(_ tableView: UITableView, dataItemForIndexPath indexPath: IndexPath) -> AnyObject
    
    func tableView(_ tableView: UITableView, moveDataItemFromIndexPath from: IndexPath, toIndexPath to : IndexPath) -> Void
    func tableView(_ tableView: UITableView, insertDataItem dataItem : AnyObject, atIndexPath indexPath: IndexPath) -> Void
    func tableView(_ tableView: UITableView, deleteDataItemAtIndexPath indexPath: IndexPath) -> Void
    func tableView(_ tableView: UITableView, cellIsDraggableAtIndexPath indexPath: IndexPath) -> Bool
    func tableView(_ tableView: UITableView, cellIsDroppableAtIndexPath indexPath: IndexPath) -> Bool
    func tableView(_ tableView: UITableView, stylingRepresentationView: UIView) -> UIView?
    
}

public class TDDragAndDropTableView: UITableView, TDDraggable, TDDroppable {

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public var draggingPathOfCellBeingDragged : IndexPath?
    
    var iDataSource: UITableViewDataSource?
    var iDelegate: UITableViewDelegate?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
    }
    
    // MARK : KDDraggable
    public func canDragAtPoint(_ point : CGPoint) -> Bool {
        if let dataSource = self.dataSource as? TDDragAndDropTableViewDataSource,
            let indexPathOfPoint = self.indexPathForRow(at: point) {
            return dataSource.tableView(self, cellIsDraggableAtIndexPath: indexPathOfPoint)
        }
        
        return false
    }
    
    public func representationImageAtPoint(_ point : CGPoint) -> UIView? {
        
        guard let indexPath = self.indexPathForRow(at: point) else {
            return nil
        }
        
        guard let cell = self.cellForRow(at: indexPath) else {
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.isOpaque, 0)
        cell.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let imageView = UIImageView(image: image)
        imageView.frame = cell.frame
        
        return imageView
    }
    
    public func stylingRepresentationView(_ view: UIView) -> UIView? {
        guard let datasource = self.dataSource as? TDDragAndDropTableViewDataSource else {
            return nil
        }
        return datasource.tableView(self, stylingRepresentationView: view)
    }
    
    public func dataItemAtPoint(_ point : CGPoint) -> AnyObject? {
        
        guard let indexPath = self.indexPathForRow(at: point) else {
            return nil
        }
        
        guard let dragDropDS = self.dataSource as? TDDragAndDropTableViewDataSource else {
            return nil
        }
        
        return dragDropDS.tableView(self, dataItemForIndexPath: indexPath)
    }
    
    public func startDraggingAtPoint(_ point : CGPoint) -> Void {
        self.draggingPathOfCellBeingDragged = self.indexPathForRow(at: point)
        self.reloadData()
    }
    
    public func stopDragging() -> Void {
        
        if let idx = self.draggingPathOfCellBeingDragged {
            if let cell = self.cellForRow(at: idx) {
                cell.isHidden = false
            }
        }
        
        self.draggingPathOfCellBeingDragged = nil
        self.reloadData()
        
    }
    
    public func dragDataItem(_ item : AnyObject) -> Void {
        
        guard let dragDropDataSource = self.dataSource as? TDDragAndDropTableViewDataSource else {
            return
        }
        
        guard let existngIndexPath = dragDropDataSource.tableView(self, indexPathForDataItem: item) else {
            return
        }
        
        dragDropDataSource.tableView(self, deleteDataItemAtIndexPath: existngIndexPath)
        
        if self.animating {
            self.deleteRows(at: [existngIndexPath], with: .automatic)
        } else {
            self.animating = true
            self.performBatchUpdates({ () -> Void in
                self.deleteRows(at: [existngIndexPath], with: .automatic)
            }, completion: { complete -> Void in
                self.animating = false
                self.reloadData()
            })
        }
        
    }
    
    // MARK : KDDroppable
    public func canDropAtRect(_ rect : CGRect) -> Bool {
        return (self.indexPathForCellOverlappingRect(rect) != nil)
    }
    
    public func indexPathForCellOverlappingRect( _ rect : CGRect) -> IndexPath? {
        
        var overlappingArea : CGFloat = 0.0
        var cellCandidate : UITableViewCell?
        let dataSource = self.dataSource as? TDDragAndDropTableViewDataSource
        
        
        let visibleCells = self.visibleCells
        if visibleCells.count == 0 {
            return IndexPath(row: 0, section: 0)
        }
        
        if  rect.origin.y > self.contentSize.height {
            
            if dataSource?.tableView(self, cellIsDroppableAtIndexPath: IndexPath(row: visibleCells.count - 1, section: 0)) == true {
                return IndexPath(row: visibleCells.count - 1, section: 0)
            }
            return nil
        }
        
        
        for visible in visibleCells {
            
            let intersection = visible.frame.intersection(rect)
            
            if (intersection.width * intersection.height) > overlappingArea {
                
                overlappingArea = intersection.width * intersection.height
                
                cellCandidate = visible
            }
            
        }
        
        if let cellRetrieved = cellCandidate, let indexPath = self.indexPath(for: cellRetrieved), dataSource?.tableView(self, cellIsDroppableAtIndexPath: indexPath) == true {
            
            return self.indexPath(for: cellRetrieved)
        }
        
        return nil
    }
    
    fileprivate var currentInRect : CGRect?
    public func willMoveItem(_ item : AnyObject, inRect rect : CGRect) -> Void {
        
        let dragDropDataSource = self.dataSource as! TDDragAndDropTableViewDataSource // its guaranteed to have a data source
        
        if let _ = dragDropDataSource.tableView(self, indexPathForDataItem: item) { // if data item exists
            return
        }
        
        if let indexPath = self.indexPathForCellOverlappingRect(rect) {
            
            dragDropDataSource.tableView(self, insertDataItem: item, atIndexPath: indexPath)
            
            self.draggingPathOfCellBeingDragged = indexPath
            
            self.animating = true
            
            self.performBatchUpdates({ () -> Void in
                
                self.insertRows(at: [indexPath], with: .automatic)
                
            }, completion: { complete -> Void in
                
                self.animating = false
                
                // if in the meantime we have let go
                if self.draggingPathOfCellBeingDragged == nil {
                    self.reloadData()
                }
            })
            
        }
        
        currentInRect = rect
    }
    
    public var animating: Bool = false
    
    public var paging : Bool = false
    func checkForEdgesAndScroll(_ rect : CGRect) -> Void {
        
        if paging == true {
            return
        }
        
        let currentRect : CGRect = CGRect(x: self.contentOffset.x, y: self.contentOffset.y, width: self.bounds.size.width, height: self.bounds.size.height)
        var rectForNextScroll : CGRect = currentRect

        let topBoundary = CGRect(x: 0.0, y: -30.0, width: self.frame.size.width, height: 30.0)
        let bottomBoundary = CGRect(x: 0.0, y: self.frame.size.height, width: self.frame.size.width, height: 30.0)
        
        if rect.intersects(topBoundary) == true {
            rectForNextScroll.origin.y -= self.bounds.size.height * 0.5
            if rectForNextScroll.origin.y < 0 {
                rectForNextScroll.origin.y = 0
            }
        }
        else if rect.intersects(bottomBoundary) == true {
            rectForNextScroll.origin.y += self.bounds.size.height * 0.5
            if rectForNextScroll.origin.y > self.contentSize.height - self.bounds.size.height {
                rectForNextScroll.origin.y = self.contentSize.height - self.bounds.size.height
            }
        }
        
        // check to see if a change in rectForNextScroll has been made
        if currentRect.equalTo(rectForNextScroll) == false {
            self.paging = true
            self.scrollRectToVisible(rectForNextScroll, animated: true)
            
            let delayTime = DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                self.paging = false
            }
        }
    }
    
    public func didMoveItem(_ item : AnyObject, inRect rect : CGRect) -> Void {
        
        let dragDropDS = self.dataSource as! TDDragAndDropTableViewDataSource // guaranteed to have a ds
        
        if  let existingIndexPath = dragDropDS.tableView(self, indexPathForDataItem: item),
            let indexPath = self.indexPathForCellOverlappingRect(rect) {
            
            if indexPath.item != existingIndexPath.item {
                
                dragDropDS.tableView(self, moveDataItemFromIndexPath: existingIndexPath, toIndexPath: indexPath)
                
                self.animating = true
                
                self.performBatchUpdates({ () -> Void in
                    self.moveRow(at: existingIndexPath, to: indexPath)
                }, completion: { (finished) -> Void in
                    self.animating = false
                    self.reloadData()
                })
                
                self.draggingPathOfCellBeingDragged = indexPath
            }
        }
        
        // Check Paging
        var normalizedRect = rect
        normalizedRect.origin.x -= self.contentOffset.x
        normalizedRect.origin.y -= self.contentOffset.y
        
        currentInRect = normalizedRect
    
        self.checkForEdgesAndScroll(normalizedRect)
    }
    
    public func didMoveOutItem(_ item : AnyObject) -> Void {
        
        guard let dragDropDataSource = self.dataSource as? TDDragAndDropTableViewDataSource,
            let existngIndexPath = dragDropDataSource.tableView(self, indexPathForDataItem: item) else {
                return
        }
        
        dragDropDataSource.tableView(self, deleteDataItemAtIndexPath: existngIndexPath)
        
        if self.animating {
            self.deleteRows(at: [existngIndexPath], with: .automatic)
        } else {
            self.animating = true
            self.performBatchUpdates({ () -> Void in
                self.deleteRows(at: [existngIndexPath], with: .automatic)
            }, completion: { (finished) -> Void in
                self.animating = false
                self.reloadData()
            })
            
        }
        
        if let idx = self.draggingPathOfCellBeingDragged {
            if let cell = self.cellForRow(at: idx) {
                cell.isHidden = false
            }
        }
        
        self.draggingPathOfCellBeingDragged = nil
        currentInRect = nil
    }
    
    public func dropDataItem(_ item : AnyObject, atRect : CGRect) -> Void {
        
        // show hidden cell
        if  let index = draggingPathOfCellBeingDragged,
            let cell = self.cellForRow(at: index), cell.isHidden == true {
            
            cell.alpha = 1
            cell.isHidden = false
        }
        
        currentInRect = nil
        self.draggingPathOfCellBeingDragged = nil
        self.reloadData()
    }
}
