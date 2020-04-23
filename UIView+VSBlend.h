//
//  UIView+VSBlend.h
//  VersaOCKit
//
//  Created by sheen on 2020/3/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    VSNormalBlendMode = 0,   //默认
    VSScreenBlendMode,       //滤色
    VSHardLightBlendMode,    //强光
    VSSoftLightBlendMode,    //柔光
    VSColorBurnBlendMode,    //颜色加深
    VSColorDodgeBlendMod,    //颜色减淡
    VSMultiplyBlendMode,     //正片叠底
    VSDarkenBlendMode,       //变暗
    VSLightenBlendMode,      //变亮
    VSOverlayBlendMode,      //覆盖叠加混合
    VSInvalidBlend           //大于等于则非法
} VSBlendMode;

@interface UIView (VSBlend)
- (void)setVSBlendMode:(VSBlendMode)blendMode;
@end

@interface CALayer (VSBlend)
- (void)setVSBlendMode:(VSBlendMode)blendMode;
@end

NS_ASSUME_NONNULL_END
