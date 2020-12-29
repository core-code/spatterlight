//
//  MetaDataReader.m
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-30.
//

#import "MetaDataReader.h"


#include "babel_handler.h"
#include "ifiction.h"
#include "treaty.h"

@implementation MetaDataReader

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _metaData = [[NSMutableDictionary alloc] init];
        ifidbuf = [[NSMutableArray alloc] init];
        metabuf = [[NSMutableDictionary alloc] init];
        [self parseFile:url.path];
    }
    return self;
}

- (NSString*)parseFile:(NSString*)path
{
    char buf[TREATY_MINIMUM_EXTENT];
    NSMutableDictionary *dict;
    NSString *ifid;
    char *format;
    char *s;
    int mdlen;
    int rv;

    NSArray *gGameFileTypes = @[
        @"d$$",   @"dat", @"sna",    @"advsys", @"quill", @"l9",  @"mag",
        @"a3c",   @"acd", @"agx",    @"gam",    @"t3",    @"hex", @"taf",
        @"z3",    @"z4",  @"z5",     @"z6",    @"z7",     @"z8",    @"ulx",
        @"blb",   @"blorb", @"glb", @"gblorb", @"zlb",    @"zblorb"
    ];

//    if ([[[path pathExtension] lowercaseString] isEqualToString: @"ifiction"])
//    {
//        [self importMetadataFromFile: path];
//        return nil;
//    }

    
    if (![gGameFileTypes containsObject: [[path pathExtension] lowercaseString]])
    {

        NSLog(@"Can not recognize the file extension.");
        return nil;
    }

    format = babel_init((char*)[path UTF8String]);
    if (!format || !babel_get_authoritative())
    {
        NSLog(@"Babel can not identify the file format.");
        babel_release();
        return nil;
    }

    s = strchr(format, ' ');
    if (s) format = s+1;

    rv = babel_treaty(GET_STORY_FILE_IFID_SEL, buf, sizeof buf);
    if (rv <= 0)
    {
        NSLog(@"Can not compute IFID from the file.");
        babel_release();
        return nil;
    }

    s = strchr(buf, ',');
    if (s) *s = 0;
    ifid = [NSString stringWithUTF8String: buf];

    NSLog(@"MetaDataReader: import game %@ (%s)", path, format);

    mdlen = babel_treaty(GET_STORY_FILE_METADATA_EXTENT_SEL, NULL, 0);
    if (mdlen > 0)
    {
        char *mdbuf = malloc(mdlen);
        if (!mdbuf)
        {

            NSLog(@"Can not allocate memory for the metadata text.");
            babel_release();
            return nil;
        }

        rv = babel_treaty(GET_STORY_FILE_METADATA_SEL, mdbuf, mdlen);
        if (rv > 0)
        {
            [self importMetadataFromXML: mdbuf];
        }

        free(mdbuf);
    }

    dict = [_metaData objectForKey: ifid];
    if (!dict)
    {
        dict = [NSMutableDictionary dictionary];
        [self addMetadata: dict forIFIDs: [NSArray arrayWithObject: ifid]];
    }

    if (![dict objectForKey: @"format"])
        [dict setObject: [NSString stringWithUTF8String: format] forKey: @"format"];
    if (![dict objectForKey: @"title"])
        [dict setObject: [path lastPathComponent] forKey: @"title"];

    NSImage *img = nil;
    int imglen;

    imglen = babel_treaty(GET_STORY_FILE_COVER_EXTENT_SEL, NULL, 0);
    if (imglen > 0)
    {
        char *imgbuf = malloc(imglen);
        if (imgbuf) {

            rv = babel_treaty(GET_STORY_FILE_COVER_SEL, imgbuf, imglen);
            NSData *imgdata = [[NSData alloc] initWithBytesNoCopy: imgbuf length: imglen freeWhenDone: YES];
            img = [[NSImage alloc] initWithData: imgdata];
        }
    }

    if (img)
        dict[@"cover"] = img;

    babel_release();

    return ifid;
}


/*
 * Metadata is not tied to games in the library.
 * We keep it around even if the games come and go.
 * Metadata that has been edited by the user is flagged,
 * and can be exported.
 */

- (void) addMetadata: (NSMutableDictionary*)dict forIFIDs: (NSArray*)list
{
    NSUInteger count = [list count];
    int i;

    for (i = 0; i < count; i++)
    {
        NSString *ifid = [list objectAtIndex: i];
        NSDictionary *entry = [_metaData objectForKey: ifid];
        if (!entry)
        {
            [_metaData setObject: dict forKey: ifid];
        }
    }
}

- (NSString *)ifidFromFile:(NSString *)path {

    char *format = babel_init((char*)path.UTF8String);
    if (!format || !babel_get_authoritative())
    {
        NSLog(@"Babel can not identify the file format.");
        babel_release();
        return nil;
    }

    char buf[TREATY_MINIMUM_EXTENT];

    int rv = babel_treaty(GET_STORY_FILE_IFID_SEL, buf, sizeof buf);
    if (rv <= 0)
    {
        NSLog(@"Can not compute IFID from the file.", nil);
        babel_release();
        return nil;
    }

    babel_release();
    return @(buf);
}

- (void) importMetadataFromXML: (char*)mdbuf
{
    ifiction_parse(mdbuf, handleXMLCloseTag, (__bridge void *)(self), handleXMLError, (__bridge void *)(self));
    ifidbuf = nil;
    metabuf = nil;
}

static void read_xml_text(const char *rp, char *wp)
{
    /* kill initial whitespace */
    while (*rp && isspace(*rp))
        rp++;

    while (*rp)
    {
        if (*rp == '<')
        {
            if (strstr(rp, "<br/>") == rp || strstr(rp, "<br />") == rp)
            {
                *wp++ = '\n';
                *wp++ = '\n';
                rp += 5;
                if (*rp == '>')
                    rp ++;

                /* kill trailing whitespace */
                while (*rp && isspace(*rp))
                    rp++;
            }
            else
            {
                *wp++ = *rp++;
            }
        }
        else if (*rp == '&')
        {
            if (strstr(rp, "&lt;") == rp)
            {
                *wp++ = '<';
                rp += 4;
            }
            else if (strstr(rp, "&gt;") == rp)
            {
                *wp++ = '>';
                rp += 4;
            }
            else if (strstr(rp, "&amp;") == rp)
            {
                *wp++ = '&';
                rp += 5;
            }
            else
            {
                *wp++ = *rp++;
            }
        }
        else if (isspace(*rp))
        {
            *wp++ = ' ';
            while (*rp && isspace(*rp))
                rp++;
        }
        else
        {
            *wp++ = *rp++;
        }
    }

    *wp = 0;
}

- (void) handleXMLCloseTag: (struct XMLTag *)tag
{
    char bigbuf[4096];

    /* we don't parse tags after bibliographic until the next story begins... */
    if (!strcmp(tag->tag, "bibliographic"))
    {
        NSLog(@"MetaDataReader: import metadata for %@ by %@", [metabuf objectForKey: @"title"], [metabuf objectForKey: @"author"]);
        [self addMetadata: metabuf forIFIDs: ifidbuf];
        ifidbuf = nil;
        metabuf = nil;
    }

    /* we should only find ifid:s inside the <identification> tag, */
    /* which should be the first tag in a <story> */
    else if (!strcmp(tag->tag, "ifid"))
    {
        if (!ifidbuf)
        {
            ifidbuf = [[NSMutableArray alloc] initWithCapacity: 1];
            metabuf = [[NSMutableDictionary alloc] initWithCapacity: 10];
        }
        char save = *tag->end;
        *tag->end = 0;
        [ifidbuf addObject: [NSString stringWithUTF8String: tag->begin]];
        *tag->end = save;
    }

    /* only extract text from within the indentification and bibliographic tags */
    else if (metabuf)
    {
        if (tag->end - tag->begin >= sizeof(bigbuf) - 1)
            return;

        char save = *tag->end;
        *tag->end = 0;
        read_xml_text(tag->begin, bigbuf);
        *tag->end = save;

        NSString *val = [NSString stringWithUTF8String: bigbuf];

        if (!strcmp(tag->tag, "format"))
            [metabuf setObject: val forKey: @"format"];
        if (!strcmp(tag->tag, "bafn"))
            [metabuf setObject: val forKey: @"bafn"];
        if (!strcmp(tag->tag, "title"))
            [metabuf setObject: val forKey: @"title"];
        if (!strcmp(tag->tag, "author"))
            [metabuf setObject: val forKey: @"author"];
        if (!strcmp(tag->tag, "language"))
            [metabuf setObject: val forKey: @"language"];
        if (!strcmp(tag->tag, "headline"))
            [metabuf setObject: val forKey: @"headline"];
        if (!strcmp(tag->tag, "firstpublished"))
            [metabuf setObject: val forKey: @"firstpublished"];
        if (!strcmp(tag->tag, "genre"))
            [metabuf setObject: val forKey: @"genre"];
        if (!strcmp(tag->tag, "group"))
            [metabuf setObject: val forKey: @"group"];
        if (!strcmp(tag->tag, "description"))
            [metabuf setObject: val forKey: @"description"];
        if (!strcmp(tag->tag, "series"))
            [metabuf setObject: val forKey: @"series"];
        if (!strcmp(tag->tag, "seriesnumber"))
            [metabuf setObject: val forKey: @"seriesnumber"];
        if (!strcmp(tag->tag, "forgiveness"))
            [metabuf setObject: val forKey: @"forgiveness"];
    }
}

- (void) handleXMLError: (char*)msg
{
    if (strstr(msg, "Error:"))
        NSLog(@"MetaDataReader: xml: %s", msg);
}

static void handleXMLCloseTag(struct XMLTag *tag, void *ctx)
{
    [(__bridge MetaDataReader*)ctx handleXMLCloseTag: tag];
}

static void handleXMLError(char *msg, void *ctx)
{
    [(__bridge MetaDataReader*)ctx handleXMLError: msg];
}


- (BOOL) importMetadataFromFile: (NSString*)filename
{
    NSLog(@"MetaDataReader: importMetadataFromFile %@", filename);

    NSMutableData *data;

    data = [NSMutableData dataWithContentsOfFile: filename];
    if (!data)
        return NO;
    [data appendBytes: "\0" length: 1];

    [self importMetadataFromXML: [data mutableBytes]];

    return YES;
}

@end
