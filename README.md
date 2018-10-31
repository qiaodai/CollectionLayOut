# CollectionLayOut
1.自定义UICollectionFlowLayOut 支持长按 拖动Cell 交换位置 支持水平和垂直两个方位的滚动
2.支持拖动Cell 到自定义 附加的View 来选择时复制Cell 还是删除Cell 附加的View可以自己定义 在相应的代理中实现即可
2.Demo中用使用的例子，可以根据自己的需求变化




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
        
        初始化数据源
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
    
    //MARK :SCCollectionViewFlowLayout Delegate DViewataSource
     //实现支持 拖动Cell 显示删除或者复制View  
      // 显示附加的Cell
    @objc func didDisPlayAdditionalEditView(){
        if self.deleteView == nil {
            deleteView = DQDeleteView()
            deleteView!.frame = CGRect.init(x: 0, y: self.collectionView.frame.origin.y - 60, width: kScreenW, height: 60)
            deleteView!.isHidden = true
            self.view.addSubview(deleteView!)
        }
        self.deleteView?.isHidden = false
    }
     // 拖动Cell 过程可以实时判断 Cell位置  本人Demo中 用来显示删除的虚框
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
    // 拖动Cell 过程可以判断Cell 是否要删除
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
     // 拖动Cell 过程可以判断Cell 是否要复制
    @objc func draggingViewIsInDuplicationEditView(_ dragView: UIView?)->Bool{
        return false
    }
    
     // 结束显示附加的 DeleteView
    @objc func didDisAppearAdditionalEditView(){
        self.deleteView?.isHidden = true
    }
    // 交换Cell位置
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, willMoveToIndexPath toIndexPath: IndexPath){
        mediaArray.exchangeObject(at: toIndexPath.row, withObjectAt: fromIndexPath.row)
    }
    
    //是否可以 移动Cell的位置
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathCanMove indexPath: IndexPath) -> Bool{
        return true
    }
    //判断两个Cell是否可以 交换位置
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPath fromIndexPath: IndexPath, canMoveToIndexPath toIndexPath: IndexPath) -> Bool{
        if labs(fromIndexPath.row - toIndexPath.row) > 1{
            return false
        }
        return true
    }
    //删除Cell
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDelete indexPath: IndexPath){
      
        mediaArray.removeObject(at: indexPath.row)
        collectionView.deleteItems(at: [indexPath])
    }
    
    //  实现复制功能的代理
    @objc func collectionView(_ collectionView: UICollectionView, itemAtIndexPathDidDuplicate indexPath: IndexPath) {
        

    }
