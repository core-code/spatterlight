//
//  MyCoreDataCoreSpotlightDelegate.m
//  Spatterlight
//
//  Created by Administrator on 2021-10-11.
//
#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>
#import <CoreSpotlight/CoreSpotlight.h>

#import "MyCoreDataCoreSpotlightDelegate.h"
#import "Image.h"
#import "Metadata.h"
#import "Game.h"
#import "Ifid.h"
#import "NSImage+Categories.h"


@implementation MyCoreDataCoreSpotlightDelegate

/* CoreSpotlight domain identifer; default is the store's identifier */
- (NSString *)domainIdentifier {
    return @"net.ccxvii.spatterlight";
}

/* CoreSpotlight index name; default nil */
- (nullable NSString *)indexName {
    return @"spatterlight-index";
}

+ (NSString *)UTIFromFormat:(NSString *)format {
    return [NSString stringWithFormat:@"public.%@", format];
}

- (nullable CSSearchableItemAttributeSet *)attributeSetForObject:(NSManagedObject*)object {
    CSSearchableItemAttributeSet *attributeSet = [super attributeSetForObject:object];

    NSLog(@"Object is kind of class %@", [object class]);

    CSCustomAttributeKey *forgiveness = [[CSCustomAttributeKey alloc] initWithKeyName:@"forgiveness"];
    CSCustomAttributeKey *group = [[CSCustomAttributeKey alloc] initWithKeyName:@"group"];
    CSCustomAttributeKey *series = [[CSCustomAttributeKey alloc] initWithKeyName:@"series"];
    CSCustomAttributeKey *date = [[CSCustomAttributeKey alloc] initWithKeyName:@"date"];

    if ([object isKindOfClass:[Image class]]) {
        Image *image = (Image *)object;
        if (!image.imageDescription.length)
            return nil;
        if (!image.metadata.count || !image.metadata.anyObject.ifids.count)
            return nil;
        if (!attributeSet)
            attributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.image"];
        attributeSet.displayName = [NSString stringWithFormat:@"Cover image of %@", image.metadata.anyObject.title];
        attributeSet.contentDescription = image.imageDescription;
        return attributeSet;
    } else if ([object isKindOfClass:[Metadata class]]) {
        Metadata *metadata = (Metadata *)object;
        if (!metadata.format.length)
            return nil;
        if (!attributeSet)
            attributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:[MyCoreDataCoreSpotlightDelegate UTIFromFormat:metadata.format]];
        if (!metadata.title.length)
            return nil;
        attributeSet.displayName = metadata.title;
        attributeSet.rating = @(metadata.starRating.integerValue);
        attributeSet.contentDescription = metadata.blurb;

        attributeSet.artist = metadata.author;
        attributeSet.genre = metadata.genre;
        attributeSet.originalFormat = metadata.format;
        if (metadata.languageAsWord.length)
            attributeSet.languages = @[metadata.languageAsWord];

        [attributeSet setValue:metadata.group forCustomKey:group];
        [attributeSet setValue:metadata.forgiveness forCustomKey:forgiveness];
        [attributeSet setValue:metadata.series forCustomKey:series];
        [attributeSet setValue:metadata.firstpublished forCustomKey:date];

        for (Ifid *ifidobject in metadata.ifids) {
            [MyCoreDataCoreSpotlightDelegate addKeyword:ifidobject.ifidString toAttributeSet:attributeSet];
        }

        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.group toAttributeSet:attributeSet];
        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.forgiveness toAttributeSet:attributeSet];
        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.series toAttributeSet:attributeSet];
        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.firstpublished toAttributeSet:attributeSet];
        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.seriesnumber toAttributeSet:attributeSet];
        [MyCoreDataCoreSpotlightDelegate addKeyword:metadata.languageAsWord toAttributeSet:attributeSet];
    }

    return attributeSet;
}

+ (void)addKeyword:(NSString *)keyword toAttributeSet:(CSSearchableItemAttributeSet *)set {
    if (!keyword.length)
        return;
    if (set.keywords == nil) {
        set.keywords = @[keyword];
    } else {
        set.keywords = [set.keywords arrayByAddingObject:keyword];
    }
}

/* CSSearchableIndexDelegate conformance */
- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void))acknowledgementHandler {
    NSLog(@"reindexAllSearchableItemsWithAcknowledgementHandler %@", searchableIndex);

    [super searchableIndex:searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:acknowledgementHandler];
}

- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexSearchableItemsWithIdentifiers:(NSArray <NSString *> *)identifiers acknowledgementHandler:(void (^)(void))acknowledgementHandler {

    NSLog(@"reindexSearchableItemsWithIdentifiers %@", searchableIndex);

    [super searchableIndex:searchableIndex reindexSearchableItemsWithIdentifiers:identifiers acknowledgementHandler:acknowledgementHandler];
}

@end
