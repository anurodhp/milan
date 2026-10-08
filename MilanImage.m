#import "MilanImage.h"
#include <stdio.h>
#include <setjmp.h>
#include <jpeglib.h>

#define MAX_DIM 2560

struct milan_jpeg_err {
	struct jpeg_error_mgr pub;
	jmp_buf jb;
};

static void
milan_jpeg_exit(j_common_ptr c)
{
	longjmp(((struct milan_jpeg_err *)c->err)->jb, 1);
}

static NSImage *
loadJPEG(NSString *path)
{
	struct jpeg_decompress_struct cinfo;
	struct milan_jpeg_err jerr;
	FILE *fp = fopen([path fileSystemRepresentation], "rb");
	NSBitmapImageRep *rep = nil;
	unsigned char *pixels = NULL;
	int denom = 1;
	if (!fp) return nil;
	cinfo.err = jpeg_std_error(&jerr.pub);
	jerr.pub.error_exit = milan_jpeg_exit;
	if (setjmp(jerr.jb)) {
		jpeg_destroy_decompress(&cinfo);
		fclose(fp);
		free(pixels);
		return nil;
	}
	jpeg_create_decompress(&cinfo);
	jpeg_stdio_src(&cinfo, fp);
	jpeg_read_header(&cinfo, TRUE);
	cinfo.out_color_space = JCS_RGB;
	while (denom < 8 && (cinfo.image_width / denom > MAX_DIM || cinfo.image_height / denom > MAX_DIM)) denom *= 2;
	cinfo.scale_num = 1;
	cinfo.scale_denom = (unsigned)denom;
	jpeg_start_decompress(&cinfo);
	{
		size_t stride = (size_t)cinfo.output_width * 3;
		pixels = malloc(stride * cinfo.output_height);
		if (!pixels) longjmp(jerr.jb, 1);
		while (cinfo.output_scanline < cinfo.output_height) {
			unsigned char *row = pixels + stride * cinfo.output_scanline;
			jpeg_read_scanlines(&cinfo, &row, 1);
		}
		jpeg_finish_decompress(&cinfo);
		rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: cinfo.output_width pixelsHigh: cinfo.output_height
		        bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace
		        bytesPerRow: (NSInteger)stride bitsPerPixel: 24] autorelease];
		memcpy([rep bitmapData], pixels, stride * cinfo.output_height);
	}
	free(pixels);
	jpeg_destroy_decompress(&cinfo);
	fclose(fp);
	{
		NSImage *img = [[[NSImage alloc] initWithSize: NSMakeSize([rep pixelsWide] * denom, [rep pixelsHigh] * denom)] autorelease];
		[img addRepresentation: rep];
		return img;
	}
}

NSImage *
MilanLoadImage(NSString *path)
{
	NSString *e = [[path pathExtension] lowercaseString];
	if ([e isEqualToString: @"jpg"] || [e isEqualToString: @"jpeg"]) return loadJPEG(path);
	return [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
}

unsigned char *
MilanJPEGPixels(NSString *path, int maxDim, int *width, int *height)
{
	struct jpeg_decompress_struct cinfo;
	struct milan_jpeg_err jerr;
	FILE *fp = fopen([path fileSystemRepresentation], "rb");
	unsigned char *pixels = NULL;
	int denom = 1;
	if (!fp) return NULL;
	cinfo.err = jpeg_std_error(&jerr.pub);
	jerr.pub.error_exit = milan_jpeg_exit;
	if (setjmp(jerr.jb)) {
		jpeg_destroy_decompress(&cinfo);
		fclose(fp);
		free(pixels);
		return NULL;
	}
	jpeg_create_decompress(&cinfo);
	jpeg_stdio_src(&cinfo, fp);
	jpeg_read_header(&cinfo, TRUE);
	cinfo.out_color_space = JCS_RGB;
	while (denom < 8 && cinfo.image_width / (denom * 2) >= (unsigned)maxDim && cinfo.image_height / (denom * 2) >= (unsigned)maxDim) denom *= 2;
	cinfo.scale_num = 1;
	cinfo.scale_denom = (unsigned)denom;
	jpeg_start_decompress(&cinfo);
	{
		size_t stride = (size_t)cinfo.output_width * 3;
		pixels = malloc(stride * cinfo.output_height);
		if (!pixels) longjmp(jerr.jb, 1);
		while (cinfo.output_scanline < cinfo.output_height) {
			unsigned char *row = pixels + stride * cinfo.output_scanline;
			jpeg_read_scanlines(&cinfo, &row, 1);
		}
		jpeg_finish_decompress(&cinfo);
		*width = (int)cinfo.output_width;
		*height = (int)cinfo.output_height;
	}
	jpeg_destroy_decompress(&cinfo);
	fclose(fp);
	return pixels;
}
