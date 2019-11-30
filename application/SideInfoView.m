//
//  SideInfoView.m
//  Spatterlight
//
//  Created by Administrator on 2018-09-09.
//

#import "SideInfoView.h"

@implementation SideInfoView

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];

	if (self)
	{
        libctl = ((AppDelegate *)([NSApplication sharedApplication].delegate)).libctl;
		ifidField = libctl.sideIfid;
	}
	return self;
}

- (BOOL) isFlipped { return YES; }

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSTextField class]])
	{
		NSTextField *textfield = notification.object;
		NSLog(@"controlTextDidEndEditing");

		if (textfield == titleField)
		{
			game.metadata.title = titleField.stringValue;
		}
		else if (textfield == headlineField)
		{
			game.metadata.headline = headlineField.stringValue;
		}
		else if (textfield == authorField)
		{
			game.metadata.author = authorField.stringValue;
		}
		else if (textfield == blurbField)
		{
			game.metadata.blurb = blurbField.stringValue;
		}
		else if (textfield == ifidField)
		{
			game.metadata.ifid = [ifidField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		}

		dispatch_async(dispatch_get_main_queue(), ^{[textfield.window makeFirstResponder:nil];});
	}
	[self viewDidEndLiveResize];
	[libctl updateTableViews];
}

- (NSTextField *) addSubViewWithtext:(NSString *)text andFont:(NSFont *)font andSpaceBefore:(CGFloat)space andLastView:(id)lastView
{

	NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];

	para.minimumLineHeight = font.pointSize + 3;
	para.maximumLineHeight = para.minimumLineHeight;

	if (font.pointSize > 40)
		para.maximumLineHeight = para.maximumLineHeight + 3;

	if (font.pointSize > 25)
		para.maximumLineHeight = para.maximumLineHeight + 3;

	para.alignment = NSCenterTextAlignment;
	para.lineSpacing = 1;

	if (font.pointSize > 25)
		para.lineSpacing = 0.2f;

	NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 font,
								 NSFontAttributeName,
								 para,
								 NSParagraphStyleAttributeName,
								 nil];

	NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:text attributes:attr];


	if (font.pointSize == 13.f)
	{
		[attrString addAttribute:NSKernAttributeName value:@1.f range:NSMakeRange(0, text.length)];
	}

	CGRect contentRect = [attrString boundingRectWithSize:CGSizeMake(self.frame.size.width - 24, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
	// I guess the magic number -24 here means that the text field inner width differs 4 points from the outer width. 2-point border?

	NSTextField *textField = [[NSTextField alloc] initWithFrame:contentRect];

	textField.translatesAutoresizingMaskIntoConstraints = NO;

	textField.bezeled=NO;
	textField.drawsBackground = NO;
	textField.editable = YES;
	textField.selectable = YES;
	textField.bordered = NO;
	[textField.cell setUsesSingleLineMode:NO];
	textField.allowsEditingTextAttributes = YES;

	textField.delegate = self;

	[textField.cell setWraps:YES];
	[textField.cell setScrollable:NO];

	[textField setContentCompressionResistancePriority:25 forOrientation:NSLayoutConstraintOrientationHorizontal];
	[textField setContentCompressionResistancePriority:25 forOrientation:NSLayoutConstraintOrientationVertical];

	NSLayoutConstraint *xPosConstraint = [NSLayoutConstraint constraintWithItem:textField
												  attribute:NSLayoutAttributeLeft
												  relatedBy:NSLayoutRelationEqual
													 toItem:self
												  attribute:NSLayoutAttributeLeft
												 multiplier:1.0
												   constant:10];

	NSLayoutConstraint *yPosConstraint;

	if (lastView)
	{
		yPosConstraint = [NSLayoutConstraint constraintWithItem:textField
													  attribute:NSLayoutAttributeTop
													  relatedBy:NSLayoutRelationEqual
														 toItem:lastView
													  attribute:NSLayoutAttributeBottom
													 multiplier:1.0
													   constant:space];
	}
	else
	{
		yPosConstraint = [NSLayoutConstraint constraintWithItem:textField
													  attribute:NSLayoutAttributeTop
													  relatedBy:NSLayoutRelationEqual
														 toItem:self
													  attribute:NSLayoutAttributeTop
													 multiplier:1.0
													   constant:space];
	}

	NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:textField
												   attribute:NSLayoutAttributeWidth
												   relatedBy:NSLayoutRelationEqual
													  toItem:self
												   attribute:NSLayoutAttributeWidth
												  multiplier:1.0
													constant:-20];

	NSLayoutConstraint *rightMarginConstraint = [NSLayoutConstraint constraintWithItem:textField
																			 attribute:NSLayoutAttributeRight
																			 relatedBy:NSLayoutRelationEqual
																				toItem:self
																			 attribute:NSLayoutAttributeRight
																			multiplier:1.0
																			  constant:-10];

	textField.attributedStringValue = attrString;

	[self addSubview:textField];

	[self addConstraint:xPosConstraint];
	[self addConstraint:yPosConstraint];
	[self addConstraint:widthConstraint];
	[self addConstraint:rightMarginConstraint];

	NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:textField
																		attribute:NSLayoutAttributeHeight
																		relatedBy:NSLayoutRelationGreaterThanOrEqual
																		   toItem:nil
																		attribute:NSLayoutAttributeNotAnAttribute
																	   multiplier:1.0
																		 constant: contentRect.size.height + 1];

	[self addConstraint:heightConstraint];
	return textField;
}


- (void) updateSideViewForGame:(Game *)agame
{
	NSLayoutConstraint *xPosConstraint;
	NSLayoutConstraint *yPosConstraint;
	NSLayoutConstraint *widthConstraint;
	NSLayoutConstraint *heightConstraint;
	NSLayoutConstraint *rightMarginConstraint;

	NSFont *font;
	CGFloat spaceBefore;
	NSView *lastView;

	self.translatesAutoresizingMaskIntoConstraints = NO;

	NSClipView *clipView = (NSClipView *)self.superview;
	NSScrollView *scrollView = (NSScrollView *)clipView.superview;
	CGFloat superViewWidth = clipView.frame.size.width;

    if (superViewWidth < 24)
        return;

	[clipView addConstraint:[NSLayoutConstraint constraintWithItem:self
														 attribute:NSLayoutAttributeLeft
														 relatedBy:NSLayoutRelationEqual
															toItem:clipView
														 attribute:NSLayoutAttributeLeft
														multiplier:1.0
														  constant:0]];

	[clipView addConstraint:[NSLayoutConstraint constraintWithItem:self
														 attribute:NSLayoutAttributeRight
														 relatedBy:NSLayoutRelationEqual
															toItem:clipView
														 attribute:NSLayoutAttributeRight
														multiplier:1.0
														  constant:0]];

	[clipView addConstraint:[NSLayoutConstraint constraintWithItem:self
														 attribute:NSLayoutAttributeTop
														 relatedBy:NSLayoutRelationEqual
															toItem:clipView
														 attribute:NSLayoutAttributeTop
														multiplier:1.0
														  constant:0]];

	if (agame.metadata.cover.data)
	{

		NSImage *theImage = [[NSImage alloc] initWithData:(NSData *)agame.metadata.cover.data];

		CGFloat ratio = theImage.size.width / theImage.size.height;

		// We make the image double size to make enlarging when draggin divider to the right work
		theImage.size = NSMakeSize(superViewWidth * 2, superViewWidth * 2 / ratio );

		NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0,0,theImage.size.width,theImage.size.height)];

		[self addSubview:imageView];

		imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
		imageView.translatesAutoresizingMaskIntoConstraints = NO;

		imageView.imageScaling = NSImageScaleProportionallyUpOrDown;

		xPosConstraint = [NSLayoutConstraint constraintWithItem:imageView
													  attribute:NSLayoutAttributeLeft
													  relatedBy:NSLayoutRelationEqual
														 toItem:self
													  attribute:NSLayoutAttributeLeft
													 multiplier:1.0
													   constant:0];

		yPosConstraint = [NSLayoutConstraint constraintWithItem:imageView
													  attribute:NSLayoutAttributeTop
													  relatedBy:NSLayoutRelationEqual
														 toItem:self
													  attribute:NSLayoutAttributeTop
													 multiplier:1.0
													   constant:0];

		widthConstraint = [NSLayoutConstraint constraintWithItem:imageView
													   attribute:NSLayoutAttributeWidth
													   relatedBy:NSLayoutRelationGreaterThanOrEqual
														  toItem:self
													   attribute:NSLayoutAttributeWidth
													  multiplier:1.0
														constant:0];

		heightConstraint = [NSLayoutConstraint constraintWithItem:imageView
														attribute:NSLayoutAttributeHeight
														relatedBy:NSLayoutRelationLessThanOrEqual
														   toItem:imageView
														attribute:NSLayoutAttributeWidth
													   multiplier:( 1 / ratio)
														 constant:0];

		rightMarginConstraint = [NSLayoutConstraint constraintWithItem:imageView
															 attribute:NSLayoutAttributeRight
															 relatedBy:NSLayoutRelationEqual
																toItem:self
															 attribute:NSLayoutAttributeRight
															multiplier:1.0
															  constant:0];

		[self addConstraint:xPosConstraint];
		[self addConstraint:yPosConstraint];
		[self addConstraint:widthConstraint];
		[self addConstraint:heightConstraint];
		[self addConstraint:rightMarginConstraint];

		imageView.image = theImage;

		lastView = imageView;

	}
	else
	{
//		NSLog(@"No image");
	}

	if (agame.metadata.title) // Every game will have a title unless something is broken
	{

		font = [NSFont fontWithName:@"Playfair Display Black" size:30];

		NSFontDescriptor *descriptor = font.fontDescriptor;

		NSArray *array = @[@{NSFontFeatureTypeIdentifierKey : @(kNumberCaseType),
							 NSFontFeatureSelectorIdentifierKey : @(kUpperCaseNumbersSelector)}];

		descriptor = [descriptor fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute : array}];

		if (agame.metadata.title.length > 9)
		{
			font = [NSFont fontWithDescriptor:descriptor size:30];
            //NSLog(@"Long title (length = %lu), smaller text.", agame.metadata.title.length);
		}
		else
		{
			font = [NSFont fontWithDescriptor:descriptor size:50];
		}

		NSString *longestWord = @"";

		for (NSString *word in [agame.metadata.title componentsSeparatedByString:@" "])
		{
			if (word.length > longestWord.length) longestWord = word;
		}
		//NSLog (@"Longest word: %@", longestWord);

		// The magic number -24 means 10 points of margin and two points of textfield border on each side.
		while ([longestWord sizeWithAttributes:@{ NSFontAttributeName:font }].width > superViewWidth - 24)
		{
//            NSLog(@"Font too large! Width %f, max allowed %f", [longestWord sizeWithAttributes:@{NSFontAttributeName:font}].width,  superViewWidth - 24);
			font = [[NSFontManager sharedFontManager] convertFont:font toSize:font.pointSize - 2];
		}
		//		NSLog(@"Font not too large! Width %f, max allowed %f", [longestWord sizeWithAttributes:@{NSFontAttributeName:font}].width,  superViewWidth - 24);

		spaceBefore = [@"X" sizeWithAttributes:@{NSFontAttributeName:font}].height * 0.7;

		lastView = [self addSubViewWithtext:agame.metadata.title andFont:font andSpaceBefore:spaceBefore andLastView:lastView];

		titleField = (NSTextField *)lastView;
	}
	else
	{
		NSLog(@"Error! No title!");
		titleField = nil;
		return;
	}

	NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, superViewWidth, 1)];

	divider.boxType = NSBoxSeparator;
	divider.translatesAutoresizingMaskIntoConstraints = NO;


	xPosConstraint = [NSLayoutConstraint constraintWithItem:divider
												  attribute:NSLayoutAttributeLeft
												  relatedBy:NSLayoutRelationEqual
													 toItem:self
												  attribute:NSLayoutAttributeLeft
												 multiplier:1.0
												   constant:0];

	yPosConstraint = [NSLayoutConstraint constraintWithItem:divider
												  attribute:NSLayoutAttributeTop
												  relatedBy:NSLayoutRelationEqual
													 toItem:lastView
												  attribute:NSLayoutAttributeBottom
												 multiplier:1.0
												   constant:spaceBefore * 0.9];

	widthConstraint = [NSLayoutConstraint constraintWithItem:divider
												   attribute:NSLayoutAttributeWidth
												   relatedBy:NSLayoutRelationEqual
													  toItem:self
												   attribute:NSLayoutAttributeWidth
												  multiplier:1.0
													constant:0];

	heightConstraint = [NSLayoutConstraint constraintWithItem:divider
													attribute:NSLayoutAttributeHeight
													relatedBy:NSLayoutRelationEqual
													   toItem:nil
													attribute:NSLayoutAttributeNotAnAttribute
												   multiplier:1.0
													 constant:1];

	[self addSubview:divider];

	[self addConstraint:xPosConstraint];
	[self addConstraint:yPosConstraint];
	[self addConstraint:widthConstraint];
	[self addConstraint:heightConstraint];

	lastView = divider;

	if (agame.metadata.headline)
	{
		//font = [NSFont fontWithName:@"Playfair Display Regular" size:13];
        font = [NSFont fontWithName:@"HoeflerText-Regular" size:16];

		NSFontDescriptor *descriptor = font.fontDescriptor;

		NSArray *array = @[@{ NSFontFeatureTypeIdentifierKey : @(kLetterCaseType),
							 NSFontFeatureSelectorIdentifierKey : @(kSmallCapsSelector)}];

		descriptor = [descriptor fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute : array}];
		font = [NSFont fontWithDescriptor:descriptor size:16.f];

		lastView = [self addSubViewWithtext:(agame.metadata.headline).lowercaseString andFont:font andSpaceBefore:4 andLastView:lastView];

		headlineField = (NSTextField *)lastView;
	}
	else
	{
//		NSLog(@"No headline");
		headlineField = nil;
	}

	if (agame.metadata.author)
	{
		font = [NSFont fontWithName:@"Gentium Plus Italic" size:14.f];

		lastView = [self addSubViewWithtext:agame.metadata.author andFont:font andSpaceBefore:25 andLastView:lastView];

		authorField = (NSTextField *)lastView;
	}
	else
	{
//		NSLog(@"No author");
		authorField = nil;
	}

	if (agame.metadata.blurb)
	{
		font = [NSFont fontWithName:@"Gentium Plus" size:14.f];

		lastView = [self addSubViewWithtext:agame.metadata.blurb andFont:font andSpaceBefore:23 andLastView:lastView];

		blurbField = (NSTextField *)lastView;

	}
	else
	{
//		NSLog(@"No blurb.");
		blurbField = nil;
	}

	NSLayoutConstraint *bottomPinConstraint = [NSLayoutConstraint constraintWithItem:self
																		   attribute:NSLayoutAttributeBottom
																		   relatedBy:NSLayoutRelationEqual
																			  toItem:lastView
																		   attribute:NSLayoutAttributeBottom
																		  multiplier:1.0
																			constant:0];
	[self addConstraint:bottomPinConstraint];

	if (game != agame)
	{
		[clipView scrollToPoint: NSMakePoint(0.0, 0.0)];
		[scrollView reflectScrolledClipView:clipView];
	}

	game = agame;
}

@end
