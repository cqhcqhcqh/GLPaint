/*
     File: PaintingView.m
 Abstract: The class responsible for the finger painting. The class wraps the 
 CAEAGLLayer from CoreAnimation into a convenient UIView subclass. The view 
 content is basically an EAGL surface you render your OpenGL scene into.
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

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>
#import "UIColor+Versa.h"
#import "PaintingView.h"
#import "shaderUtil.h"
#import "fileUtil.h"
#import "debug.h"

//CONSTANTS:

#define kBrushOpacity		1.0
#define kBrushPixelStep		3
#define kBrushScale			2


// Shaders
enum {
    PROGRAM_POINT,
    PROGRAM_BACKGROUND,
    NUM_PROGRAMS
};

enum {
	UNIFORM_MVP,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_LASTPOINT,
    UNIFORM_CURRENTPOINT,
    UNIFORM_LINEWIDTH,
    UNIFORM_LINEBLURWIDTH,
    UNIFORM_SCREENTSIZE,
    UNIFORM_ERASER,
	NUM_UNIFORMS
};

enum {
	ATTRIB_VERTEX,
    ATTRIB_TEXTURE_VERTEX,
	NUM_ATTRIBS
};

typedef struct {
	char *vert, *frag;
	GLint uniform[NUM_UNIFORMS];
	GLuint id;
} programInfo_t;

programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
    { "background.vsh", "background.fsh"},
};


// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;


@interface PaintingView()
{
	// The pixel dimensions of the backbuffer
	GLint backingWidth;
	GLint backingHeight;
	
	EAGLContext *context;
	
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;
	
	textureInfo_t backgroundTexture;     // brush texture
    textureInfo_t maskTexture;     // brush texture
    GLfloat brushColor[4];          // brush color
    
	Boolean	firstTouch;
	Boolean needsErase;
    
    // Shader objects
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    // Buffer Objects
    GLuint vboId;
    
    BOOL initialized;
}

@end

@implementation PaintingView

@synthesize  location;
@synthesize  previousLocation;

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        [self setup];
    }
    
    return self;
}

- (void)setup {
    // 在init的方法中，从基类获取layer属性，并将其转型至CAEAGLLayer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!context || ![EAGLContext setCurrentContext:context]) {
        return;
    }
    
    // Set the view's scale factor as you wish
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
    self.backgroundColor = [UIColor clearColor];
    
    brushColor[0] = 1.0;
    brushColor[1] = 0.2;
    brushColor[2] = 0.4;
    // Make sure to start with a cleared buffer
    needsErase = YES;
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
-(void)layoutSubviews
{
	[EAGLContext setCurrentContext:context];
    
    if (!initialized) {
        initialized = [self initGL];
    }
    else {
        [self resizeFromLayer:(CAEAGLLayer*)self.layer];
    }
	
	// Clear the framebuffer the first time it is allocated
	if (needsErase) {
		[self erase];
		needsErase = NO;
	}
}

- (void)setupShaders
{
	for (int i = 0; i < NUM_PROGRAMS; i++)
	{
		char *vsrc = readFile(pathForResource(program[i].vert));
		char *fsrc = readFile(pathForResource(program[i].frag));
		GLsizei attribCt = 0;
		GLchar *attribUsed[NUM_ATTRIBS];
		GLint attrib[NUM_ATTRIBS];
        if (i == PROGRAM_POINT) {
            GLchar *attribName[NUM_ATTRIBS] = {
                "inVertex",
            };
            const GLchar *uniformName[NUM_UNIFORMS] = {
                "MVP", "vertexColor", "u_lastPoint", "u_currentPoint", "u_lineWidth", "u_lineBlurWidth", "u_screenSize", "u_eraser"
            };
            
            // auto-assign known attribs
            for (int j = 0; j < NUM_ATTRIBS - 1; j++)
            {
                if (strstr(vsrc, attribName[j]))
                {
                    attrib[attribCt] = j;
                    attribUsed[attribCt++] = attribName[j];
                }
            }
            
            glueCreateProgram(vsrc, fsrc,
                              attribCt, (const GLchar **)&attribUsed[0], attrib,
                              NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                              &program[i].id);
        } else if (i == PROGRAM_BACKGROUND) {
            GLchar *attribName[NUM_ATTRIBS] = {
                "inVertex",
                "inTextureVertex",
            };
            const GLchar *uniformName[3] = {
//                "MVP",
                "texture0",
                "texture1",
            };
            
            // auto-assign known attribs
            for (int j = 0; j < 1; j++)
            {
                if (strstr(vsrc, attribName[j]))
                {
                    attrib[attribCt] = j;
                    attribUsed[attribCt++] = attribName[j];
                }
            }
            
            glueCreateProgram(vsrc, fsrc,
                              attribCt, (const GLchar **)&attribUsed[0], attrib,
                              2, &uniformName[0], program[i].uniform,
                              &program[i].id);
            
            glUseProgram(program[PROGRAM_BACKGROUND].id);
            // glUniform1i设置每个采样器的方式告诉OpenGL每个着色器采样器属于哪个纹理单元
            // location textureid
            glUniform1i(0, 0);
            glUniform1i(1, 1);
            
//            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
//            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
//            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
//            glUniformMatrix4fv(program[PROGRAM_BACKGROUND].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
        }
		
		free(vsrc);
		free(fsrc);
        
        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);
            
            // the brush texture will be bound to texture unit 0
//            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            // viewing matrices
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
        
            // point size
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_LINEWIDTH], 50.0);
            
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_LINEBLURWIDTH], 50.0);
                        
            glUniform2f(program[PROGRAM_POINT].uniform[UNIFORM_SCREENTSIZE], UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
        }
	}
    
    glError();
}

// Create a texture from an image
- (textureInfo_t)textureFromName:(NSString *)name
{
    CGImageRef		brushImage;
	CGContextRef	brushContext;
	GLubyte			*brushData;
	size_t			width, height;
    GLuint          texId;
    textureInfo_t   texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:name].CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    
    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &texId);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, texId);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        // Release  the image data; it's no longer needed
        free(brushData);
        
        texture.id = texId;
        texture.width = (int)width;
        texture.height = (int)height;
    }
    
    return texture;
}

- (BOOL)initGL
{
    // Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffers(1, &viewFramebuffer);
	glGenRenderbuffers(1, &viewRenderbuffer);
	
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
	
	// For this sample, we do not need a depth buffer. If you do, this is how you can create one and attach it to the framebuffer:
//    glGenRenderbuffers(1, &depthRenderbuffer);
//    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
//    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
//    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFE
	if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Update projection matrix
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    glUseProgram(program[PROGRAM_POINT].id);
    glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
    
    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &vboId);
    
    glActiveTexture(GL_TEXTURE0);
    backgroundTexture = [self textureFromName:@"display"];
    glActiveTexture(GL_TEXTURE1);
    maskTexture = [self textureFromName:@"maskImage"];
    
    // Load shaders
    [self setupShaders];
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
//        glEnable(GL_BLEND);
    glDisable(GL_BLEND);
    //    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self drawBackgroundImage];
    });
    return YES;
}

- (void)drawBackgroundImage {
    [EAGLContext setCurrentContext:context];
    
    GLfloat or_vertex[] = {
        -1.0, 1.0, 0.0, 0.0,
        -1.0, -1.0, 0.0, 1.0,
        1.0, 1.0, 1.0, 0.0,
        1.0, -1.0, 1.0, 1.0,
    };
    
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, 16*sizeof(GLfloat), or_vertex, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRIB_TEXTURE_VERTEX);
    glVertexAttribPointer(ATTRIB_TEXTURE_VERTEX, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 2*sizeof(GLfloat));
    
    // Draw
    glUseProgram(program[PROGRAM_BACKGROUND].id);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // For this sample, we do not need a depth buffer. If you do, this is how you can allocate depth buffer backing:
//    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
//    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
//    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Update projection matrix
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    glUseProgram(program[PROGRAM_POINT].id);
    glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
	
    return YES;
}

// Releases resources when they are not longer needed.
- (void)dealloc
{
    // Destroy framebuffers and renderbuffers
	if (viewFramebuffer) {
        glDeleteFramebuffers(1, &viewFramebuffer);
        viewFramebuffer = 0;
    }
    if (viewRenderbuffer) {
        glDeleteRenderbuffers(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
	if (depthRenderbuffer)
	{
		glDeleteRenderbuffers(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
    // texture
    if (backgroundTexture.id) {
		glDeleteTextures(1, &backgroundTexture.id);
		backgroundTexture.id = 0;
	}
    // vbo
    if (vboId) {
        glDeleteBuffers(1, &vboId);
        vboId = 0;
    }
    
    // tear down context
	if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
}

// Erases the screen
- (void)erase
{
	[EAGLContext setCurrentContext:context];
	
	// Clear the buffer
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Display the buffer
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER];
}

// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
	[EAGLContext setCurrentContext:context];
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
	
	// Convert locations from Points to Pixels
	CGFloat scale = self.contentScaleFactor;
	start.x *= scale;
	start.y *= scale;
	end.x *= scale;
	end.y *= scale;
    
    float or_vertex[] = {
        -1.0, 1.0,
        -1.0, -1.0,
        1.0, 1.0,
        1.0, -1.0,
    };
    
    glUniform2f(program[PROGRAM_POINT].uniform[UNIFORM_LASTPOINT], start.x, start.y);
    
    glUniform2f(program[PROGRAM_POINT].uniform[UNIFORM_CURRENTPOINT], end.x, end.y);
    
	// Load data to the Vertex Buffer Object
	glBindBuffer(GL_ARRAY_BUFFER, vboId);
	glBufferData(GL_ARRAY_BUFFER, 8*sizeof(GLfloat), or_vertex, GL_DYNAMIC_DRAW);
	
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);
	    
	// Draw
    glUseProgram(program[PROGRAM_POINT].id);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
	// Display the buffer
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER];
}

// Reads previously recorded points and draws them onscreen. This is the Shake Me message that appears when the application launches.
- (void)playback:(NSMutableArray*)recordedPaths
{
    // NOTE: Recording.data is stored with 32-bit floats
    // To make it work on both 32-bit and 64-bit devices, we make sure we read back 32 bits each time.
    
    Float32 x[1], y[1];
    CGPoint point1, point2;
    
	NSData*				data = [recordedPaths objectAtIndex:0];
	NSUInteger			count = [data length] / (sizeof(Float32)*2), // each point contains 64 bits (32-bit x and 32-bit y)
						i;
	
	// Render the current path
	for(i = 0; i < count - 1; i++) {
        
        [data getBytes:&x range:NSMakeRange(8*i, sizeof(Float32))]; // read 32 bits each time
        [data getBytes:&y range:NSMakeRange(8*i+sizeof(Float32), sizeof(Float32))];
        point1 = CGPointMake(x[0], y[0]);
        
        [data getBytes:&x range:NSMakeRange(8*(i+1), sizeof(Float32))];
        [data getBytes:&y range:NSMakeRange(8*(i+1)+sizeof(Float32), sizeof(Float32))];
        point2 = CGPointMake(x[0], y[0]);
        
        [self renderLineFromPoint:point1 toPoint:point2];
    }
	
	// Render the next path after a short delay 
	[recordedPaths removeObjectAtIndex:0];
	if([recordedPaths count])
		[self performSelector:@selector(playback:) withObject:recordedPaths afterDelay:0.01];
}


// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{   
	CGRect				bounds = [self bounds];
    UITouch*            touch = [[event touchesForView:self] anyObject];
//	firstTouch = YES;
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
	location = [touch locationInView:self];
	location.y = bounds.size.height - location.y;
}

// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{   
	CGRect				bounds = [self bounds];
	UITouch*			touch = [[event touchesForView:self] anyObject];
		
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
//	if (firstTouch) {
//		firstTouch = NO;
//		previousLocation = [touch previousLocationInView:self];
//		previousLocation.y = bounds.size.height - previousLocation.y;
//	} else {
		location = [touch locationInView:self];
	    location.y = bounds.size.height - location.y;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
//	}
		
	// Render the stroke
	[self renderLineFromPoint:previousLocation toPoint:location];
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGRect				bounds = [self bounds];
    UITouch*            touch = [[event touchesForView:self] anyObject];
//	if (firstTouch) {
		firstTouch = NO;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
		[self renderLineFromPoint:previousLocation toPoint:location];
//	}
}

// Handles the end of a touch event.
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	// If appropriate, add code necessary to save the state of the application.
	// This application is not saving state.
}

- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    return;
	// Update the brush color
    brushColor[0] = red * kBrushOpacity;
    brushColor[1] = green * kBrushOpacity;
    brushColor[2] = blue * kBrushOpacity;
    brushColor[3] = kBrushOpacity;
    
    if (initialized) {
        glUseProgram(program[PROGRAM_POINT].id);
        glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    }
}


- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)eraserPaint:(BOOL)isEraser {
    glUseProgram(program[PROGRAM_POINT].id);
    glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_ERASER], isEraser);
}

- (void)updateLineWidth:(CGFloat)lineWidth {
    glUseProgram(program[PROGRAM_POINT].id);
    glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_LINEWIDTH], lineWidth);
}

- (void)updateBlurWidth:(CGFloat)lineWidth {
    glUseProgram(program[PROGRAM_POINT].id);
    glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_LINEBLURWIDTH], lineWidth);
}

@end
