/*
 File: color.fsh
 Abstract: A fragment shader that draws points with assigned color and 
 texture.
 Version: 1.13
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */
#extension GL_EXT_shader_framebuffer_fetch : require

//uniform sampler2D texture;
//varying lowp vec4 color;
precision mediump float;

uniform vec2 u_resolution;
uniform vec2 u_lastPoint;
uniform vec2 u_currentPoint;
uniform float u_lineWidth;
uniform float u_lineBlurWidth;

float pointToSegDist(vec2 pt, vec2 pa, vec2 pb) {
    highp vec2 ab = pb - pa;
    highp float len = length(ab);
    if (len == 0.0) return distance(pt, pa);
    highp vec2 at = pt - pa;
    highp float f = dot(ab, at);
    if (f < 0.0) return distance(pt, pa);
    highp float d = dot(ab, ab);
    if (f > d) return distance(pt, pb);
    f = f / d;
    highp vec2 pu = f * ab + pa;
    return distance(pt, pu);
}

void main() {
//    highp vec2 last = vec2(u_lastPoint.x * u_resolution.x, u_lastPoint.y * u_resolution.y);
//    highp vec2 current = vec2(u_currentPoint.x * u_resolution.x, u_currentPoint.y * u_resolution.y);
//    highp float dist = pointToSegDist(gl_FragCoord.xy, last, current);
//    if(dist > u_lineWidth / 2.0) discard;
//    highp float blurStart = (u_lineWidth - u_lineBlurWidth)/2.0;
//    highp float enable= step(dist, blurStart);
//    gl_FragColor = vec4( 1.0, 0.0, 0.0, enable + (1.0 - ((dist - blurStart)/ u_lineBlurWidth * 2.0)) * (1.0 - enable));
    gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0);
}
