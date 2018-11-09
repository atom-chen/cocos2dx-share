/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.3
 * 
 * Copyright (c) 2013-2015, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to use, install, execute and perform the Spine
 * Runtimes Software (the "Software") and derivative works solely for personal
 * or internal use. Without the written permission of Esoteric Software (see
 * Section 2 of the Spine Software License Agreement), you may not (a) modify,
 * translate, adapt or otherwise create derivative works, improvements of the
 * Software or develop new applications using the Software or (b) remove,
 * delete, alter or obscure any trademarks or any copyright, trademark, patent
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/spine-cocos2dx.h>
#include <spine/extension.h>

USING_NS_CC;

/* 根据atlas中的图片缓存纹理，并且做retain操作*/
void _spAtlasPage_createTexture (spAtlasPage* self, const char* path) {
	Texture2D* texture = Director::getInstance()->getTextureCache()->addImage(path);
	texture->retain();
	self->rendererObject = texture;
	self->width = texture->getPixelsWide();
	self->height = texture->getPixelsHigh();
}

/* 将atlas中需要我们缓存的图片 release掉 */
void _spAtlasPage_disposeTexture (spAtlasPage* self) {
	((Texture2D*)self->rendererObject)->release();
}

char* _spUtil_readFile (const char* path, long* length) {
    Data data;
//    clock_t start = clock();
    static std::map<std::string, Data> _s_chached_skeleton_json_data;
    auto iter = _s_chached_skeleton_json_data.find(path);
    if (iter == _s_chached_skeleton_json_data.end()){
        data = FileUtils::getInstance()->getDataFromFile(FileUtils::getInstance()->fullPathForFilename(path));
        _s_chached_skeleton_json_data.insert(std::make_pair(path, data));
        CCLOG("cached [%s] , first using",path);
    }else{
        CCLOG("already cached [%s] , use it right now",path);
        data = iter->second;
    }
	*length = data.getSize();
	char* bytes = MALLOC(char, *length);
    memcpy(bytes, data.getBytes(), *length);
    
    static bool flag = false;
    if (flag == false) {
        //异步更新之后需要重新加载下动画配置文件，以免spine错乱
        auto _backToForegroundlistener = EventListenerCustom::create("REMOVE_UNUSED_SPINE_DATA", [&](EventCustom*) {
            std::map<std::string, Data> tmp;
            _s_chached_skeleton_json_data.swap(tmp);
            CCLOG("清空骨骼配置文件");
        });
        Director::getInstance()->getEventDispatcher()->addEventListenerWithFixedPriority(_backToForegroundlistener, -1);
        flag = true;
        CCLOG("添加骨骼配置文件监听");
    }
//    clock_t end = clock();
//    CCLOG("解析[%s]耗时:%f",path , (double)(end - start) /1000000);
	return bytes;
}
