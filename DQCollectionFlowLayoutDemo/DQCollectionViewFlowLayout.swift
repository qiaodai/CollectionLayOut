//
//  DQCollectionViewFlowLayout.swift
//  DQCollectionFlowLayoutDemo
//
//  Created by wond on 2018/10/31.
//  Copyright © 2018年 wond. All rights reserved.
//

import UIKit
import QuartzCore

public enum DQScrollingDirection {
    case unknown
    case up
    case down
    case left
    case right
}

extension UICollectionViewCell{
    public func snapshotView()-> UIView{
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0);
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image:UIImage = UIGraphicsGetImageFromCurrentImageContext()!;
        UIGraphicsEndImageContext();
        return UIImageView.init(image: image);
    }
}


@objc public protocol DQCollectionViewDataSource:UICollectionViewDataSource{
    
    @objc optional func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, willMoveToIndexPath toIndexPath: IndexPath)
    @objc optional func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, didMoveToIndexPath toIndexPath: IndexPath)
    
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathCanMove indexPath: IndexPath) -> Bool
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, canMoveToIndexPath toIndexPath: IndexPath) -> Bool
    
    @objc optional func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDelete indexPath: IndexPath)
    @objc optional func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDuplicate indexPath: IndexPath)
}

@objc protocol DQCollectionViewDelegateFlowLayout:UICollectionViewDelegateFlowLayout{
    
    @objc optional func didDisPlayAdditionalEditView()
    @objc optional func draggingViewMoving(_ dragView: UIView?)
    @objc optional func draggingViewIsInDeleteEditView(_ dragView: UIView?)->Bool
    @objc optional func draggingViewIsInDuplicationEditView(_ dragView: UIView?)->Bool
    @objc optional func didDisAppearAdditionalEditView()
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, didBeginDraggingItemAtIndexPath: IndexPath)
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, willEndDraggingItemAtIndexPath: IndexPath)
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, didEndDraggingItemAtIndexPath: IndexPath)
}


class DQCollectionViewFlowLayout: UICollectionViewFlowLayout,UIGestureRecognizerDelegate {
    
    fileprivate var scuserInfo:NSMutableDictionary?
    
    var scrollingSpeed:CGFloat = 0
    
    var scrollingTriggerEdgeInsets:UIEdgeInsets?
    
    var longPressGestureRecognizer:UILongPressGestureRecognizer? = nil
    
    var panGestureRecognizer:UIPanGestureRecognizer? = nil
    /*
     * 滚动过程中是否需要缩放Cell
     */
    var scrollingNeedToZoomCell: Bool = false
    
    /**
     * 长按是否需要放大dragView
     */
    var dragViewScale: CGFloat = 1.2
    /**
     *  建议设置值 1.0 - 2.0 之间
     */
    var zoomScale: CGFloat = 2.0
    
    weak var dataSource:AnyObject?{
        return self.collectionView?.dataSource
    }
    
    weak var delegate:AnyObject?{
        return self.collectionView?.delegate 
    }
    
    fileprivate var selectedItemIndexPath:IndexPath? = nil
    
    fileprivate var currentView:UIView? = nil
    
    fileprivate var currentViewCenter:CGPoint? = nil
    
    fileprivate var panTranslationInCollectionView:CGPoint? = nil
    
    fileprivate var displayLink:CADisplayLink? = nil

    
    override init() {
        super.init()
        self.scrollingSpeed = 300
        self.scrollingTriggerEdgeInsets = UIEdgeInsets.init(top: 50.0, left: 50.0, bottom: 50.0, right: 50.0)
        self.addObserver(self, forKeyPath: "collectionView", options: NSKeyValueObservingOptions.new, context: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.scrollingSpeed = 300
        self.scrollingTriggerEdgeInsets = UIEdgeInsets.init(top: 50.0, left: 50.0, bottom: 50.0, right: 50.0)
        self.addObserver(self, forKeyPath: "collectionView", options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    deinit {
        self.invalidatesScrollTimer()
        self.tearDownCollectionView()
        self.removeObserver(self, forKeyPath: "collectionView")
    }
    
    func setupCollectionView(){
        self.longPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPressGesture(gestureRecognizer:)))
        self.longPressGestureRecognizer?.delegate = self;

        self.collectionView!.addGestureRecognizer(self.longPressGestureRecognizer!)
        self.panGestureRecognizer = UIPanGestureRecognizer.init(target: self, action: #selector(handlePanGesture(gestureRecognizer:)))
        self.panGestureRecognizer?.delegate = self
        self.collectionView!.addGestureRecognizer(self.panGestureRecognizer!)
 
    }

    func tearDownCollectionView(){
        if (self.longPressGestureRecognizer != nil) {
            let view:UIView? = self.longPressGestureRecognizer!.view;
            if view != nil {
                view!.removeGestureRecognizer(self.longPressGestureRecognizer!)
            }
            self.longPressGestureRecognizer!.delegate = nil;
            self.longPressGestureRecognizer = nil;
        }
        
        // Tear down pan gesture
        if (self.panGestureRecognizer != nil) {
            let view:UIView? = self.panGestureRecognizer!.view;
            if view != nil {
                view!.removeGestureRecognizer(self.panGestureRecognizer!)
            }
            self.panGestureRecognizer?.delegate = nil;
            self.panGestureRecognizer = nil;
        }
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }
    
    func setLayoutIfNeeded(){
        let viewCenter:CGPoint = UIApplication.shared.keyWindow!.convert(self.currentView!.center, to: self.collectionView!)
        let newIndexPath:IndexPath? = self.collectionView!.indexPathForItem(at: viewCenter)
        let previousIndexPath:IndexPath? = self.selectedItemIndexPath
        
        guard newIndexPath != nil && newIndexPath!.compare(previousIndexPath!) != ComparisonResult.orderedSame else {
            return
        }

        if self.dataSource!.responds(to: #selector(DQCollectionViewDataSource.collectionView(_:itemAtIndexPath:canMoveToIndexPath:))) {
            let status:Bool = self.dataSource!.collectionView!(self.collectionView!, itemAtIndexPath: previousIndexPath!, canMoveToIndexPath: newIndexPath!)
            if !status {
                return
            }
        }
        self.selectedItemIndexPath = newIndexPath
        if self.dataSource!.responds(to: #selector(DQCollectionViewDataSource.collectionView(_:itemAtIndexPath:willMoveToIndexPath:))){
            self.dataSource!.collectionView!(self.collectionView!, itemAtIndexPath: previousIndexPath!, willMoveToIndexPath: newIndexPath!)
            
        }
        weak var weakSelf = self
        self.collectionView?.performBatchUpdates({
            weakSelf?.collectionView?.deleteItems(at: [previousIndexPath!])
            weakSelf?.collectionView?.insertItems(at: [newIndexPath!])
        }, completion: { (finish) in
            if (weakSelf?.collectionView?.responds(to: #selector(DQCollectionViewDataSource.collectionView(_:itemAtIndexPath:didMoveToIndexPath:))))!{
                weakSelf?.dataSource?.collectionView!((weakSelf?.collectionView!)!, itemAtIndexPath: previousIndexPath!, didMoveToIndexPath: newIndexPath!)
            }
        })
    }
    
    func invalidatesScrollTimer(){
        if self.displayLink != nil && !(self.displayLink!.isPaused) {
            self.displayLink!.invalidate()
        }
    }
    
    func setupScrollTimerInDirection(direction:DQScrollingDirection){
        if self.displayLink != nil && !(self.displayLink!.isPaused) {
            let oldDirection:DQScrollingDirection? = self.scuserInfo?["DQScrollingDirection"] as? DQScrollingDirection
            if direction == oldDirection {
                return
            }
        }
        self.invalidatesScrollTimer()
        self.displayLink = CADisplayLink.init(target: self, selector: #selector(handleScroll(displayLink:)))
        self.scuserInfo = ["DQScrollingDirection" : direction ];
        self.displayLink!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
    }
    
    @objc func handleScroll(displayLink:CADisplayLink){
        let direction:DQScrollingDirection = (self.scuserInfo?["DQScrollingDirection"] as? DQScrollingDirection)!
        if direction == DQScrollingDirection.unknown {
            return
        }
        let frameSize:CGSize = self.collectionView!.bounds.size
        let contentSize:CGSize = self.collectionView!.contentSize
        let contentOffset:CGPoint = self.collectionView!.contentOffset
        let contentInset:UIEdgeInsets = self.collectionView!.contentInset
        var distance:CGFloat = rint(self.scrollingSpeed * CGFloat(displayLink.duration));
        var translation:CGPoint = CGPoint.zero;
        switch direction {
        case .up:
            distance = -distance
            let minY:CGFloat = 0.0 - contentInset.top
            if (contentOffset.y + distance) <= minY {
                 distance = -contentOffset.y - contentInset.top
            }
            translation = CGPoint.init(x: 0.0, y: distance)
        case .down:
            let maxY:CGFloat = max(contentSize.height, frameSize.height) - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            translation = CGPoint.init(x:0.0, y:distance);
        case .left:
            distance = -distance;
            let minX:CGFloat = 0.0 - contentInset.left;
            
            if ((contentOffset.x + distance) <= minX) {
                distance = -contentOffset.x - contentInset.left;
            }
            translation = CGPoint.init(x:distance, y:0.0);
        case .right:
            let maxX:CGFloat = max(contentSize.width, frameSize.width) - frameSize.width + contentInset.right;
            if ((contentOffset.x + distance) >= maxX) {
                distance = maxX - contentOffset.x;
            }
            translation = CGPoint.init(x:distance, y:0.0);
        default:
            break
        }
        self.collectionView?.contentOffset = CGPoint.init(x: contentOffset.x + translation.x, y: contentOffset.y + translation.y);
    }
    @objc func handleLongPressGesture(gestureRecognizer:UILongPressGestureRecognizer){
       
        switch gestureRecognizer.state {
        case .began:
            let currentIndexPath:IndexPath? = (self.collectionView!.indexPathForItem(at: gestureRecognizer.location(in: self.collectionView)))
            guard currentIndexPath != nil && self.delegate != nil && self.dataSource != nil else {
                return
            }
            let status:Bool = self.dataSource!.collectionView(self.collectionView!, itemAtIndexPathCanMove: currentIndexPath!)
            guard status == true else {
                return
            }
            
            self.selectedItemIndexPath = currentIndexPath
            
            self.delegate?.didDisPlayAdditionalEditView?()
        
            let collectionViewCell:UICollectionViewCell = (self.collectionView?.cellForItem(at: self.selectedItemIndexPath!))!
            let frame = UIApplication.shared.keyWindow!.convert(collectionViewCell.frame, from: self.collectionView!)

            self.currentView = UIView.init(frame: frame)
            
            let imageView = collectionViewCell.snapshotView()
            var arm2:UIViewAutoresizing = UIViewAutoresizing.init(rawValue: 0)
            arm2.formUnion(UIViewAutoresizing.flexibleWidth)
            arm2.formUnion(UIViewAutoresizing.flexibleHeight)
            imageView.autoresizingMask = arm2
            imageView.alpha = 1.0
            
            self.currentView!.addSubview(imageView)
            self.currentView!.clipsToBounds = true
            UIApplication.shared.keyWindow!.addSubview(self.currentView!)
            self.currentViewCenter = self.currentView!.center
            
            UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.beginFromCurrentState, animations: {
                self.currentView?.transform = CGAffineTransform(scaleX: self.dragViewScale, y: self.dragViewScale)
            }, completion: { (finish) in
                if self.delegate!.responds(to: #selector(DQCollectionViewDelegateFlowLayout.collectionView(_:layout:didBeginDraggingItemAtIndexPath:))) {
                    self.delegate!.collectionView!(self.collectionView!, layout: self, didBeginDraggingItemAtIndexPath: self.selectedItemIndexPath!)
                }
            })
            self.invalidateLayout()
        case .cancelled, .ended:
         
            let currentIndexPath:IndexPath? = self.selectedItemIndexPath
            if currentIndexPath == nil {
                return
            }
            if (self.delegate?.responds(to: #selector(DQCollectionViewDelegateFlowLayout.collectionView(_:layout:willEndDraggingItemAtIndexPath:))))!{
                self.delegate?.collectionView!(self.collectionView!, layout: self, willEndDraggingItemAtIndexPath: currentIndexPath!)
            }
            let layoutAttributes:UICollectionViewLayoutAttributes? = self.layoutAttributesForItem(at: currentIndexPath!)
   
            self.selectedItemIndexPath = nil
            self.currentViewCenter = CGPoint.zero
            self.longPressGestureRecognizer?.isEnabled = false

            UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.beginFromCurrentState, animations: {
                var tempPoint = CGPoint.init()
                let status = self.delegate!.draggingViewIsInDeleteEditView?(self.currentView)
                if status != nil && status == true  {
                    self.currentView?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
                    tempPoint = self.collectionView!.convert(layoutAttributes!.center, to: UIApplication.shared.keyWindow!)
                    tempPoint.y =  self.currentView!.center.y
                }else{
                    self.currentView?.transform = CGAffineTransform.identity
                    tempPoint = self.collectionView!.convert(layoutAttributes!.center, to: UIApplication.shared.keyWindow!)
                }
                self.currentView?.center = tempPoint
                
            }, completion: { (finish) in

                // delete or Dupulication
                let isDelete = self.delegate!.draggingViewIsInDeleteEditView?(self.currentView)
                let isDupulication = self.delegate!.draggingViewIsInDuplicationEditView?(self.currentView)
                
                self.longPressGestureRecognizer?.isEnabled = true
                self.currentView?.removeFromSuperview()
                self.currentView = nil
                self.invalidateLayout()
                
                // end Drag
                if self.delegate!.responds(to: #selector(DQCollectionViewDelegateFlowLayout.collectionView(_:layout:didEndDraggingItemAtIndexPath:))) {
                    self.delegate!.collectionView!(self.collectionView!, layout: self, didEndDraggingItemAtIndexPath: currentIndexPath!)
                }
                if isDelete != nil && isDelete ==  true {
                    if self.dataSource!.responds(to: #selector(DQCollectionViewDataSource.collectionView(_:itemAtIndexPathDidDelete:))) {
                        self.dataSource!.collectionView!(self.collectionView!, itemAtIndexPathDidDelete: currentIndexPath!)
                    }
                }
                if isDupulication != nil && isDupulication == true {
                    if self.dataSource!.responds(to: #selector(DQCollectionViewDataSource.collectionView(_:itemAtIndexPathDidDuplicate:))) {
                        self.dataSource!.collectionView!(self.collectionView!, itemAtIndexPathDidDuplicate: currentIndexPath!)
                    }
                }
                self.delegate!.didDisAppearAdditionalEditView?()
            })
            
        default:
            break
        }
    }
    @objc func handlePanGesture(gestureRecognizer:UIPanGestureRecognizer){
        switch gestureRecognizer.state {
        case .began,.changed:
            guard self.currentView != nil else {
                return
            }
            self.panTranslationInCollectionView = gestureRecognizer.translation(in: self.collectionView);
            self.currentView!.center = CGPoint.init(x: (self.currentViewCenter!.x + self.panTranslationInCollectionView!.x), y: (self.currentViewCenter!.y + self.panTranslationInCollectionView!.y))
            let viewCenter:CGPoint = UIApplication.shared.keyWindow!.convert(self.currentView!.center, to: self.collectionView!)

            self.setLayoutIfNeeded()
            
            delegate?.draggingViewMoving(self.currentView)
            
            switch self.scrollDirection {
            case UICollectionViewScrollDirection.vertical:
                if (viewCenter.y < (self.collectionView!.bounds.minY + self.scrollingTriggerEdgeInsets!.top)) {
                    self.setupScrollTimerInDirection(direction: .up)
                } else {
                    if (viewCenter.y > (self.collectionView!.bounds.maxY - self.scrollingTriggerEdgeInsets!.bottom)) {
                        self.setupScrollTimerInDirection(direction: .down)
                    } else {
                        self.invalidatesScrollTimer()
                    }
                }
            case UICollectionViewScrollDirection.horizontal:
                
                if (viewCenter.x < ((self.collectionView!.bounds.minX + self.scrollingTriggerEdgeInsets!.left))) {
                    self.setupScrollTimerInDirection(direction: .left)
                } else {
                    if (viewCenter.x > ((self.collectionView!.bounds.maxX - self.scrollingTriggerEdgeInsets!.right))) {
                        self.setupScrollTimerInDirection(direction: .right)
                    } else {
                        self.invalidatesScrollTimer()
                    }
                }
            }
        case .cancelled,.ended:
            self.invalidatesScrollTimer()
        default:break
        }
    }
    //MARK:  UICollectionViewLayout overridden methods
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributesForElementsInRect:[UICollectionViewLayoutAttributes] = super.layoutAttributesForElements(in: rect)!;
        for layoutAttributes in layoutAttributesForElementsInRect{
            switch layoutAttributes.representedElementCategory {
            case UICollectionElementCategory.cell:
                self.applyLayoutAttributes(layoutAttributes: layoutAttributes)
            default:
                break
            }
        }
        return layoutAttributesForElementsInRect;
    }

    override func layoutAttributesForItem(at indexPath:IndexPath) -> UICollectionViewLayoutAttributes{
        let layoutAttributes:UICollectionViewLayoutAttributes = super.layoutAttributesForItem(at: indexPath)!
        switch layoutAttributes.representedElementCategory{
            case UICollectionElementCategory.cell:
                self.applyLayoutAttributes(layoutAttributes:layoutAttributes)
            default: break;
        }
        return layoutAttributes;
    }
    
    
    func applyLayoutAttributes(layoutAttributes:UICollectionViewLayoutAttributes){
        if layoutAttributes.indexPath == self.selectedItemIndexPath {
            layoutAttributes.isHidden = true
        }

        if scrollingNeedToZoomCell {
            let centerX = self.collectionView!.contentOffset.x + self.collectionView!.frame.size.width * 0.5
            let delta = abs(layoutAttributes.center.x - centerX)
            let scale = 1 - delta / (self.collectionView!.frame.size.width * self.zoomScale)
            layoutAttributes.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        var contentFrame: CGRect = CGRect.init()
        contentFrame.size = collectionView!.frame.size
        contentFrame.origin = proposedContentOffset

        let array = layoutAttributesForElements(in: contentFrame)
        
        switch self.scrollDirection {
        case UICollectionViewScrollDirection.vertical:
            var minCenterY = CGFloat.greatestFiniteMagnitude
            let collectionViewCenterY = proposedContentOffset.y + collectionView!.frame.size.height*0.5
            for attrs in array! {
                if abs(attrs.center.y - collectionViewCenterY) < abs(minCenterY) {
                    minCenterY = attrs.center.y - collectionViewCenterY
                }
            }
            var y:CGFloat = proposedContentOffset.y + minCenterY
            if  y <= 0 {
                y = 0
            } else {
                y -= 1
            }
            let point = CGPoint.init(x: proposedContentOffset.x, y: y)
            return point

        case UICollectionViewScrollDirection.horizontal:

            var minCenterX = CGFloat.greatestFiniteMagnitude
            let collectionViewCenterX = proposedContentOffset.x + collectionView!.frame.size.width*0.5
            for attrs in array! {
                if abs(attrs.center.x - collectionViewCenterX) < abs(minCenterX) {
                    minCenterX = attrs.center.x - collectionViewCenterX
                }
            }
            var x:CGFloat = proposedContentOffset.x + minCenterX
            if  x <= 0 {
                x = 0
            } else {
                x -= 1
            }
            let point = CGPoint.init(x: x, y: proposedContentOffset.y)
            return point
        }
    }
    //MARK:  UIGestureRecognizerDelegate methods
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.panGestureRecognizer == gestureRecognizer{
            if !(self.selectedItemIndexPath != nil) {
                return false
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (self.longPressGestureRecognizer == gestureRecognizer) {
            return (self.panGestureRecognizer == otherGestureRecognizer)
        }
        
        if (self.panGestureRecognizer == gestureRecognizer) {
            return (self.longPressGestureRecognizer == otherGestureRecognizer)
        }
        return false;
    }
    
    //MARK:  Key-Value Observing methods
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "collectionView") {
            if (self.collectionView != nil) {
                self.setupCollectionView()
            } else {
                self.invalidatesScrollTimer()
                self.tearDownCollectionView()
            }
        }
    }
}
