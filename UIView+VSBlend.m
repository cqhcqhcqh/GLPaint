//
//  UIView+VSBlend.m
//  VersaOCKit
//
//  Created by sheen on 2020/3/10.
//

#import "UIView+VSBlend.h"

@implementation UIView (VSBlend)
- (void)setVSBlendMode:(VSBlendMode)blendMode
{
    [self.layer setVSBlendMode:blendMode];
}
@end


@implementation CALayer (VSBlend)
- (void)setVSBlendMode:(VSBlendMode)blendMode
{
    NSArray* filterNames = @[
        @"screenBlendMode",       //滤色
        @"hardLightBlendMode",    //强光
        @"softLightBlendMode",    //柔光
        @"colorBurnBlendMode",    //颜色加深
        @"colorDodgeBlendMode",   // 颜色减淡
        @"multiplyBlendMode",     //正片叠底
        @"darkenBlendMode",       //变暗
        @"lightenBlendMode",      //变亮
        @"overlayBlendMode",      //覆盖叠加混合
    ];
    if(blendMode > VSNormalBlendMode && blendMode < VSInvalidBlend) {
        self.compositingFilter = [filterNames objectAtIndex:(blendMode - 1)];
    } else {
        self.compositingFilter = nil;
    }
}
@end
