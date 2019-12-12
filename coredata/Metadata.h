//
//  Metadata.h
//  Spatterlight
//
//  Created by Petter Sjölund on 2019-12-12.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Game, Ifid, Image, Tag;

@interface Metadata : NSManagedObject

@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSString * averageRating;
@property (nonatomic, retain) NSString * bafn;
@property (nonatomic, retain) NSString * blurb;
@property (nonatomic, retain) NSString * coverArtURL;
@property (nonatomic, retain) NSDate * dateEdited;
@property (nonatomic, retain) NSString * firstpublished;
@property (nonatomic, retain) NSDate * firstpublishedDate;
@property (nonatomic, retain) NSString * forgiveness;
@property (nonatomic, retain) NSNumber * forgivenessNumeric;
@property (nonatomic, retain) NSString * format;
@property (nonatomic, retain) NSString * genre;
@property (nonatomic, retain) NSString * group;
@property (nonatomic, retain) NSString * headline;
@property (nonatomic, retain) NSString * language;
@property (nonatomic, retain) NSString * languageAsWord;
@property (nonatomic, retain) NSString * myRating;
@property (nonatomic, retain) NSString * ratingCountTot;
@property (nonatomic, retain) NSString * series;
@property (nonatomic, retain) NSString * seriesnumber;
@property (nonatomic, retain) NSNumber * source;
@property (nonatomic, retain) NSString * starRating;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * tuid;
@property (nonatomic, retain) NSNumber * userEdited;
@property (nonatomic, retain) NSDate * lastModified;
@property (nonatomic, retain) Image *cover;
@property (nonatomic, retain) Game *game;
@property (nonatomic, retain) Tag *tag;
@property (nonatomic, retain) NSSet *ifids;
@end

@interface Metadata (CoreDataGeneratedAccessors)

- (void)addIfidObject:(Ifid *)value;
- (void)removeIfidObject:(Ifid *)value;
- (void)addIfid:(NSSet *)values;
- (void)removeIfid:(NSSet *)values;

- (Ifid *)findOrCreateIfid:(NSString *)ifidstring;

@end
