//
//  TDDragAndDropManager.swift
//  TDDragAndDropViews
//
//  Created by Phanha Uy on 9/11/18.
//  Copyright © 2018 Mäd. All rights reserved.
//

import UIKit

public protocol TDDraggable {
    func canDragAtPoint(_ point : CGPoint) -> Bool
    func representationImageAtPoint(_ point : CGPoint) -> UIView?
    func stylingRepresentationView(_ view: UIView) -> UIView?
    func dataItemAtPoint(_ point : CGPoint) -> AnyObject?
    func dragDataItem(_ item : AnyObject) -> Void
    
    /* optional */ func startDraggingAtPoint(_ point : CGPoint) -> Void
    /* optional */ func stopDragging() -> Void
}

extension TDDraggable {
    public func startDraggingAtPoint(_ point : CGPoint) -> Void {}
    public func stopDragging() -> Void {}
}


public protocol TDDroppable {
    func canDropAtRect(_ rect : CGRect) -> Bool
    func willMoveItem(_ item : AnyObject, inRect rect : CGRect) -> Void
    func didMoveItem(_ item : AnyObject, inRect rect : CGRect) -> Void
    func didMoveOutItem(_ item : AnyObject) -> Void
    func dropDataItem(_ item : AnyObject, atRect : CGRect) -> Void
}

public class TDDragAndDropManager: NSObject, UIGestureRecognizerDelegate {
    
    fileprivate var canvas : UIView = UIView()
    fileprivate var scrollView: UIScrollView? = nil
    fileprivate var views : [UIView] = []
    fileprivate var longPressGestureRecogniser = UILongPressGestureRecognizer()
    
    public var offsetToScroll: CGFloat = 0
    
    struct Bundle {
        var offset : CGPoint = CGPoint.zero
        var sourceDraggableView : UIView
        var overDroppableView : UIView?
        var snapshotView : UIView
        var dataItem : AnyObject
    }
    var bundle : Bundle?
    
    lazy var reorderGestureRecognizer: UILongPressGestureRecognizer = {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(TDDragAndDropManager.updateForLongPress(_:)))
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.3
        return gestureRecognizer
    }()
    
    public init(canvas : UIView, tableViews : [UIView]) {
        
        super.init()
        
        guard let superView = canvas.superview else {
            fatalError("Canvas must be inside a view")
        }
        if let scrollView = canvas as? UIScrollView {
            self.scrollView = scrollView
        }
        self.canvas = superView
        
        self.canvas.isMultipleTouchEnabled = false
        self.canvas.addGestureRecognizer(self.reorderGestureRecognizer)
        self.views = tableViews
    }
    
    public func append(element tableView: UIView) {
        self.views.append(tableView)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        for view in self.views where view is TDDraggable  {
            
            let draggable = view as! TDDraggable
            
            let touchPointInView = touch.location(in: view)
            
            guard draggable.canDragAtPoint(touchPointInView) == true else { continue }
            if let dataItem: AnyObject = draggable.dataItemAtPoint(touchPointInView) {
                return true
            }
        }
        
        return false
    }
    
    fileprivate var viewToDetect: UIView {
        get {
            if let view = self.scrollView {
                return view
            }
            return self.canvas
        }
    }
    
    @objc public func updateForLongPress(_ recogniser : UILongPressGestureRecognizer) -> Void {
        
        let pointOnDetectedView = recogniser.location(in: self.viewToDetect)
        let pointOnCanvas = recogniser.location(in: recogniser.view)
        
        switch recogniser.state {
        case .began :
            self.beginReorder(recogniser)
            guard let bundle = self.bundle else { return }
            self.canvas.addSubview(bundle.snapshotView)
            
            let sourceDraggable : TDDraggable = bundle.sourceDraggableView as! TDDraggable
            let pointOnSourceDraggable = recogniser.location(in: bundle.sourceDraggableView)
            sourceDraggable.startDraggingAtPoint(pointOnSourceDraggable)
        case .changed :
            guard let bundle = self.bundle else { return }
            
            let sourceDraggable : TDDraggable = bundle.sourceDraggableView as! TDDraggable
            let pointOnSourceDraggable = recogniser.location(in: bundle.sourceDraggableView)
            
            // Update the frame of the representation image
            var draggingFrame = bundle.snapshotView.frame
            draggingFrame.origin = CGPoint(x: pointOnDetectedView.x - bundle.offset.x, y: pointOnDetectedView.y - bundle.offset.y);
            
            var repImgFrame = bundle.snapshotView.frame
            repImgFrame.origin = CGPoint(x: pointOnCanvas.x - bundle.offset.x, y: pointOnCanvas.y - bundle.offset.y);
            bundle.snapshotView.frame = repImgFrame
            
            var overlappingAreaMAX: CGFloat = 0.0
            
            var mainOverView: UIView?
            
            for view in self.views where view is TDDraggable  {
                
                let viewFrameOnCanvas = self.convertRectToCanvas(view.frame, fromView: view)
                
                
                /*                 ┌────────┐   ┌────────────┐
                 *                 │       ┌┼───│Intersection│
                 *                 │       ││   └────────────┘
                 *                 │   ▼───┘│
                 * ████████████████│████████│████████████████
                 * ████████████████└────────┘████████████████
                 * ██████████████████████████████████████████
                 */
                
                let overlappingAreaCurrent = draggingFrame.intersection(viewFrameOnCanvas).area
                
                if overlappingAreaCurrent > overlappingAreaMAX {
                    
                    overlappingAreaMAX = overlappingAreaCurrent
                    
                    mainOverView = view
                }
                
                
            }
            
            if let droppable = mainOverView as? TDDroppable {
                
                let rect = viewToDetect.convert(draggingFrame, to: mainOverView)
                
                if droppable.canDropAtRect(rect) {
                    
                    if mainOverView != bundle.overDroppableView { // if it is the first time we are entering
                        
                        (bundle.overDroppableView as! TDDroppable).didMoveOutItem(bundle.dataItem)
                        droppable.willMoveItem(bundle.dataItem, inRect: rect)
                    }
                    
                    // set the view the dragged element is over
                    self.bundle!.overDroppableView = mainOverView
                    droppable.didMoveItem(bundle.dataItem, inRect: rect)
                }
            }
            
            self.checkForEdgesAndScroll(repImgFrame)
            
        case .ended, .cancelled, .failed, .possible:
            guard let bundle = self.bundle else { return }
            
            let sourceDraggable : TDDraggable = bundle.sourceDraggableView as! TDDraggable
            let pointOnSourceDraggable = recogniser.location(in: bundle.sourceDraggableView)
            
            // Update the frame of the representation image
            var draggingFrame = bundle.snapshotView.frame
            draggingFrame.origin = CGPoint(x: pointOnDetectedView.x - bundle.offset.x, y: pointOnDetectedView.y - bundle.offset.y);
            
            if bundle.sourceDraggableView != bundle.overDroppableView { // if we are actually dropping over a new view.
                
                if let droppable = bundle.overDroppableView as? TDDroppable {
                    
                    sourceDraggable.dragDataItem(bundle.dataItem)
                    
                    let rect = self.viewToDetect.convert(draggingFrame, to: bundle.overDroppableView)
                    
                    droppable.dropDataItem(bundle.dataItem, atRect: rect)
                }
            }
            
            bundle.snapshotView.removeFromSuperview()
            sourceDraggable.stopDragging()
        }
    }
    
    // MARK: - Reordering
    
    func beginReorder(_ recogniser : UILongPressGestureRecognizer) {
        for view in self.views where view is TDDraggable  {
            
            let draggable = view as! TDDraggable
            
            let touchPointInView = recogniser.location(in: view)
            
            guard draggable.canDragAtPoint(touchPointInView) == true else { continue }
            
            guard var representation = draggable.representationImageAtPoint(touchPointInView) else { continue }
            
            representation.frame = self.canvas.convert(representation.frame, from: view)
            representation.alpha = 0.5
            if let decoredView = draggable.stylingRepresentationView(representation) {
                representation = decoredView
            }
            
            let pointOnCanvas = recogniser.location(in: self.canvas)
            let offset = CGPoint(x: pointOnCanvas.x - representation.frame.origin.x, y: pointOnCanvas.y - representation.frame.origin.y)
            
            if let dataItem: AnyObject = draggable.dataItemAtPoint(touchPointInView) {
                
                self.bundle?.snapshotView.removeFromSuperview()
                self.bundle = Bundle(
                    offset: offset,
                    sourceDraggableView: view,
                    overDroppableView : view is TDDroppable ? view : nil,
                    snapshotView: representation,
                    dataItem : dataItem
                )
                
                return
            }
        }
    }
    
    // MARK: Helper Methods
    func convertRectToCanvas(_ rect : CGRect, fromView view : UIView) -> CGRect {
        
        var r = rect
        var v = view
        
        while v != self.canvas {
            
            guard let sv = v.superview else { break; }
            
            r.origin.x += sv.frame.origin.x
            r.origin.y += sv.frame.origin.y
            
            v = sv
        }
        
        return r
    }
    
    var paging = false
    func checkForEdgesAndScroll(_ rect : CGRect) {
        guard let scrollView = self.scrollView else {
            return
        }
        
        if (paging) {
            return
        }
        
        let currentRect : CGRect = CGRect(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
        var rectForNextScroll : CGRect = currentRect
        
        let isHorizantal = currentRect.height == scrollView.contentSize.height
        if (isHorizantal && currentRect.width < scrollView.contentSize.width) {
            let leftBoundary = CGRect(x: -150, y: 0.0, width: 30.0, height: scrollView.frame.size.height)
            let rightBoundary = CGRect(x: scrollView.frame.size.width + 150, y: 0.0, width: 30.0, height: scrollView.frame.size.height)
            
            if rect.intersects(leftBoundary) == true {
                rectForNextScroll.origin.x -= self.offsetToScroll
                if rectForNextScroll.origin.x < 0 {
                    rectForNextScroll.origin.x = 0
                }
            } else if rect.intersects(rightBoundary) == true {
                rectForNextScroll.origin.x += self.offsetToScroll
                if rectForNextScroll.origin.x > scrollView.contentSize.width - scrollView.bounds.size.width {
                    rectForNextScroll.origin.x = scrollView.contentSize.width - scrollView.bounds.size.width
                }
            }
        } else if (currentRect.height < scrollView.contentSize.height) {
            let topBoundary = CGRect(x: 0.0, y: -30.0, width: scrollView.frame.size.width, height: 30.0)
            let bottomBoundary = CGRect(x: 0.0, y: scrollView.frame.size.height, width: scrollView.frame.size.width, height: 30.0)
            
            if rect.intersects(topBoundary) == true {
                rectForNextScroll.origin.y -= self.offsetToScroll
                if rectForNextScroll.origin.y < 0 {
                    rectForNextScroll.origin.y = 0
                }
            }
            else if rect.intersects(bottomBoundary) == true {
                rectForNextScroll.origin.y += self.offsetToScroll
                if rectForNextScroll.origin.y > scrollView.contentSize.height - scrollView.bounds.size.height {
                    rectForNextScroll.origin.y = scrollView.contentSize.height - scrollView.bounds.size.height
                }
            }
        }
        
        // check to see if a change in rectForNextScroll has been made
        if currentRect.equalTo(rectForNextScroll) == false {
            self.paging = true
            scrollView.scrollRectToVisible(rectForNextScroll, animated: true)
            
            let delayTime = DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                self.paging = false
            }
        }
    }
}
