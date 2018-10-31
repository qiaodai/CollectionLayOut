//
//  ViewController.swift
//  DQCollectionFlowLayoutDemo
//
//  Created by wond on 2018/10/31.
//  Copyright © 2018年 wond. All rights reserved.
//

import UIKit
// 屏幕宽度
let kScreenW = UIScreen.main.bounds.width
//屏幕高度
let kScreenH = UIScreen.main.bounds.height

let kDELETE_VIEW_INSET:CGFloat = 4.0

class DQDeleteView: UIView {
    
    var drawDashLine:Bool = false{
        didSet{
            setNeedsDisplay()
        }
    }
    
    var deleteIcon:UIImageView = {
        let imageView = UIImageView()
        imageView.image = #imageLiteral(resourceName: "icon_delete")
        return imageView
    }()
    
    var titleLabel:UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.text = NSLocalizedString("Delete", comment: "")
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.red
        addSubview(deleteIcon)
        addSubview(titleLabel)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        deleteIcon.frame = CGRect.init(x: self.bounds.width/2 - 30, y: 0, width: 30, height: 30)
        deleteIcon.center.y = self.bounds.height/2
        titleLabel.frame = CGRect.init(x: self.bounds.width/2 , y: 0, width: 60, height: 21)
        titleLabel.center.y = self.bounds.height/2
        
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        if drawDashLine{
            let dashBezierPath = UIBezierPath.init(rect: CGRect.init(x: kDELETE_VIEW_INSET, y: kDELETE_VIEW_INSET, width: rect.size.width - 2*kDELETE_VIEW_INSET, height: rect.size.height - 2*kDELETE_VIEW_INSET))
            var dashArray:[CGFloat] = [CGFloat]()
            dashArray.append(5)
            dashArray.append(4)
            let context = UIGraphicsGetCurrentContext()
            context?.setLineDash(phase: 0, lengths: dashArray)
            context?.setStrokeColor(UIColor.white.cgColor)
            context?.addPath(dashBezierPath.cgPath)
            context?.strokePath()
        }
    }
}
class ViewController: UIViewController {

    var collectionView: UICollectionView!
    
    /**
     * 这个View 自己根据需求 自定义
     */
    fileprivate var deleteView: DQDeleteView?
    
    public var mediaArray:NSMutableArray = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let flowLayout:DQCollectionViewFlowLayout = DQCollectionViewFlowLayout.init()
        collectionView = UICollectionView.init(frame: CGRect.init(x: 0, y: 300, width: kScreenW, height: 60), collectionViewLayout: flowLayout)
        collectionView.alwaysBounceHorizontal = true
        flowLayout.itemSize = CGSize.init(width: 60, height: 60)
        flowLayout.scrollDirection  = UICollectionViewScrollDirection.horizontal;
        flowLayout.minimumLineSpacing  = 10;
        flowLayout.minimumInteritemSpacing  = 10;
        flowLayout.sectionInset  = UIEdgeInsetsMake(0, 8, 0, 8);
        
        flowLayout.scrollingNeedToZoomCell = true
        flowLayout.zoomScale = 1.5
        
        
        collectionView.register(DQContainerCell.self, forCellWithReuseIdentifier: "DQContainerCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.collectionViewLayout = flowLayout
        self.view.addSubview(collectionView)
        

        for i in 1..<8 {
            let str = Bundle.main.path(forResource: "\(i)", ofType: "jpg")
            self.mediaArray.add(str!)
        }
        self.collectionView.reloadData()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
extension ViewController:UICollectionViewDelegate,UICollectionViewDataSource{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int{
        return mediaArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: "DQContainerCell", for: indexPath) as!DQContainerCell
        cell.imageView.image = UIImage.init(contentsOfFile: mediaArray[indexPath.row] as! String)
        return cell
    }
    
    //MARK :SCCollectionViewFlowLayout Delegate DataSource
    @objc func didDisPlayAdditionalEditView(){
        if self.deleteView == nil {
            deleteView = DQDeleteView()
            deleteView!.frame = CGRect.init(x: 0, y: self.collectionView.frame.origin.y - 60, width: kScreenW, height: 60)
            deleteView!.isHidden = true
            self.view.addSubview(deleteView!)
        }
        self.deleteView?.isHidden = false
    }
    
    @objc func draggingViewMoving(_ dragView: UIView?){
        guard self.deleteView != nil else {
            return
        }
        let tempFrame = self.view.convert(self.deleteView!.frame, to: UIApplication.shared.keyWindow!)
        if tempFrame.contains(CGPoint.init(x: kScreenW/2, y: dragView!.center.y)) {
            deleteView!.drawDashLine = true
        }else{
            deleteView!.drawDashLine = false
        }
    }
    
    @objc func draggingViewIsInDeleteEditView(_ dragView: UIView?)->Bool{
        guard dragView != nil && self.deleteView != nil  else {
            return false
        }
        let tempFrame = self.view.convert(self.deleteView!.frame, to: UIApplication.shared.keyWindow!)
        if tempFrame.contains(CGPoint.init(x: kScreenW/2, y: dragView!.center.y)) {
            return true
        }else{
            return false
        }
    }
    
    @objc func draggingViewIsInDuplicationEditView(_ dragView: UIView?)->Bool{
        return false
    }
    
    
    @objc func didDisAppearAdditionalEditView(){
        self.deleteView?.isHidden = true
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, willMoveToIndexPath toIndexPath: IndexPath){
        mediaArray.exchangeObject(at: toIndexPath.row, withObjectAt: fromIndexPath.row)
    }
    
    
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathCanMove indexPath: IndexPath) -> Bool{
        return true
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, canMoveToIndexPath toIndexPath: IndexPath) -> Bool{
        if labs(fromIndexPath.row - toIndexPath.row) > 1{
            return false
        }
        return true
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDelete indexPath: IndexPath){
      
        mediaArray.removeObject(at: indexPath.row)
        collectionView.deleteItems(at: [indexPath])
    }
    
    //  实现复制功能的代理
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDuplicate indexPath: IndexPath) {
        

    }
}

// MARK: -
private class DQContainerCell: UICollectionViewCell {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        self.contentView.addSubview(imageView)
        return imageView
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
    }
}

