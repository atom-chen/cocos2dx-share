### 背景介绍
- 在我实际使用中，会遇到加载大量spine的情况，比如：5v5的战斗，那就至少需要10个spine动画(还不包括额外的技能特效)，每个spine对应3个文件，分别是 json、atlas、png，这时候每个spine动画就至少就需要做3次IO以及三次解码，10个一起的话总体的耗时就会比较大了。
- 此时，一般的做法是在进入战斗之前做个场景切换，在切换场景页告知玩家正在加载资源，那我们有没有办法缩短这个时间甚至不需要切换场景呢？有人会说，我们可以提前加载spine啊，但是有的时候我们无法事先知晓需要加载哪些动画，比如你查看别人的战报，你是无法事先知晓他们的人物情况的。
#### 我的思路
- 我将json\atlas与png的加载分开了，其中json和atlas做一次加载，png单独做一次加载。
- 因为我发现在加载和读取json的时候是需要大量时间解析json的，这部分一旦解析过就没必要再次解析了，因为我计算过，哪怕我缓存30-50个json，也不会对游戏内存产生多大的影响，可能还不如一张地图的场景占用内存。
- 在游戏启动的时候，我们就可以实现把常用的spine的json和atlas缓存到内存里，然后在实际使用的时候只需要加载png图片就OK，由于texture本身也有个texturecache，所以，在实际使用中，我们可以做到大部分时候都能快速进入战斗或者切换场景，缓存的策略需要自己把控，比如，哪些人物或者动画会经常用到，就优先把它放到spine的缓存里。
- 在清理内存的时候，优先清理texturecache或者只清理spine相关的texture，这样就可以既能保证玩家的体验、又能很好的控制内存，当然，如果你检测到内存比较大的时候，甚至可以再次单独清理掉json和atlas的缓存。
- 注意事项
1.游戏一般都有异步更新资源的需求，每次更新完，最好清理一下json和atlas的缓存，否则可能读取的配置还是更新之前的，从而导致动画错乱。
2.修改完之后，还需要手动绑定一些api到lua端，我使用的lua脚本。
3.我是在3.1x版本基础上修改的，但还没有同步到官方最新版本，但是我看了最新版的spine部分，差别不是很大。
##### 以上思路的实现我在实际项目中使用效果还算满意。
---
##### 关于cocostudio骨骼动画的思路
 除了spine，我在实际项目中也使用到了csb动画，我也对其做了一点点修改。
 首先，说下我对csb的理解：
 csb加载流程：
- 1.通过ArmatureDataManager预先加载csb文件：
```
	local armatureDataManager = ccs.ArmatureDataManager:getInstance()
	armatureDataManager:addArmatureFileInfo(csbFile)
```
- 2.加载csb的内部主要是抽取出ArmatureData、AnimationData、TextureData存到armatureDataManager中；
同时会配套读取对应的plist文件，将其加载到SpriteFrameCache中。
```
	SpriteFrameCache::getInstance()->addSpriteFramesWithFile(plistPath, imagePath);
```
- 3.创建CCArmature：
```
	CCArmature:create(name)
```
	如果name为空字符，则默认创建一个叫“new_armature”的Armature；
	如果name不为空，则根据name去armatureDataManager中查找是否存在对应的ArmatureData、AnimationData；
	如果查到数据，则成功创建CCArmature，否则失败；
---
#####注意事项：
- 1.csb中的数据和动画纹理数据是分开保存的，可以保存csb数据，然后将动画纹理清除掉，
下次创建的时候再去读取纹理即可，当然这部分引擎本身是不支持的，我们修改后已支持。
- 2.异步加载部分的优化，
引擎原版中的异步加载原理：
&ensp;&ensp;1).开启一个线程，内部无限循环的判断是否存在需要加载的csb文件，如果有，
就在子线程中读取并分析抽取出ArmatureData、AnimationData、TextureData存到armatureDataManager中；
&ensp;&ensp;2).csb文件在子线程读取完成后会抛到ui线程中加载对应的plist到SpriteFrameCache中(此部分会阻塞游戏)。
&ensp;&ensp;3).通知脚本端，有一个csb文件已经加载完成。
修改后的异步加载流程：
在armatureDataManager中查找是否存在对应的csb数据，
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;如果存在：
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;判断对应的plist是否已经加载：
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;是：
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;就直接返回通知脚本端
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;否：
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;开启子线程加载plist，成功后通知脚本端
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;如果不存在：
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;为每一个csb开启一个单独的线程，在子线程中读取并分析抽取出ArmatureData、AnimationData、TextureData存到armatureDataManager中；同时，会在该线程中加载对应的plist到SpriteFrameCache中；最后通知脚本端
* 3.优化后对csb文件本身也做了缓存，也就是节约了每次解析csb的时间，如果想清除这个缓存，只需要zc.dispatchEvent({name = "CLEAR_CACHED_CSB_DATA"})