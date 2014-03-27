//
//  TBModel.m
//  TBAquarium
//
//  Created by Kosuke Matsuda on 2014/03/27.
//  Copyright (c) 2014年 matsuda. All rights reserved.
//

#import "TBAquarium.h"
#import "TBModel.h"
#import "NSString+TBAquarium.h"
#import "FMDatabase+TBAquarium.h"

static FMDatabase *__database = nil;
static NSMutableDictionary *__tableCache = nil;


@interface TBModel ()

@property (nonatomic, assign) BOOL  savedInDatabase;

+ (void)assertDatabaseExists;
- (NSArray *)propertyValues;

@end


@implementation TBModel

+ (void)setDatabase:(FMDatabase *)database
{
    if (__database != database) {
        __database = database;
    }
}

+ (FMDatabase *)database
{
    return __database;
}

+ (void)assertDatabaseExists
{
    NSAssert([self database], @"Database not set.");
}

+ (NSString *)tableName
{
    NSString         *str = [[self class] description];
    NSMutableArray *parts = [NSMutableArray array];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z][a-z]*" options:0 error:nil];
    NSRange range = NSMakeRange(0, str.length);
    [regex enumerateMatchesInString:str options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [parts addObject:[str substringWithRange:[result rangeAtIndex:0]]];
    }];
    return [[[parts componentsJoinedByString:@"_"] tb_pluralizeString] lowercaseString];
}

- (FMDatabase *)database
{
    return [[self class] database];
}

#pragma mark - DB Methods

- (NSArray *)columns
{
    if (!__tableCache) {
        __tableCache = [@{} mutableCopy];
    }
    NSString *tableName = [[self class] tableName];
    NSArray *columns = [__tableCache objectForKey:tableName];

    if (!columns) {
        columns = [[self database] columnsForTableName:tableName];
        [__tableCache setObject:columns forKey:tableName];
    }
    return columns;
}

- (NSArray *)columnsWithoutPrimaryKey
{
    NSMutableArray *columns = [NSMutableArray arrayWithArray:[self columns]];
    [columns removeObjectAtIndex:0];
    return columns;
}

- (NSArray *)propertyValues
{
    NSMutableArray *values = [NSMutableArray array];

    for (NSString *column in [self columnsWithoutPrimaryKey]) {
        id value = [self valueForKey:column];
        if (value)
            [values addObject:value];
        else if ([column isEqualToString:@"createdAt"])
            [values addObject:[NSDate date]];
        else
            [values addObject:[NSNull null]];
    }
    return values;
}

- (NSArray *)propertyValuesWithColumns:(NSArray *)columns
{
    NSMutableArray *values = [@[] mutableCopy];

    for (NSString *column in [self columnsWithoutPrimaryKey]) {
        if (![columns containsObject:column]) continue ;
        id value = [self valueForKey:column];
        if (value)
            [values addObject:value];
        else if ([column isEqualToString:@"createdAt"])
            [values addObject:[NSDate date]];
        else
            [values addObject:[NSNull null]];
    }
    return values;
}

- (NSDate *)createdAt
{
    if (!_createdAt) return nil;
    NSNumber *numberOfdate = (NSNumber *)_createdAt;
    return [NSDate dateWithTimeIntervalSince1970:[numberOfdate unsignedIntegerValue]];
}

- (NSDate *)toLocalCreatedAt
{
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSDate   *date = [self createdAt];
    NSUInteger seconds = [tz secondsFromGMTForDate:date];
    return [NSDate dateWithTimeInterval:seconds sinceDate:date];
}

#pragma mark - Finder Methods

+ (NSArray *)findAll
{
    return [self findWithSql:[NSString stringWithFormat:@"SELECT * FROM %@", [self tableName]] withParameters:nil];
}

+ (NSArray *)findWithSql:(NSString *)sql withParameters:(NSArray *)parameters
{
    [self assertDatabaseExists];
    NSMutableArray *results = [@[] mutableCopy];
    FMResultSet  *resultSet = [[self database] executeQuery:sql withArgumentsInArray:parameters];
    while ([resultSet next]) {
        TBModel *model = [self new];
        [model setValuesForKeysWithDictionary:[resultSet resultDictionary]];
        model.savedInDatabase = YES;
        [results addObject:model];
    }
    return results;
}

+ (NSArray *)findWithCondition:(NSString *)condition withParameters:(NSArray *)parameters
{
    return [self findWithSql:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", [self tableName], condition] withParameters:parameters];
}

+ (NSUInteger)count
{
    NSArray *result = [self findWithSql:[NSString stringWithFormat:@"SELECT primaryKey FROM %@", [self tableName]] withParameters:nil];
    return result.count;
}

#pragma mark - CUD Methods

- (void)save
{
    [[self class] assertDatabaseExists];
    if (!_savedInDatabase) {
        [self insert];
    } else {
        [self update];
    }
}

- (void)insert
{
    NSMutableArray *parameterList = [[NSMutableArray alloc] init];
    NSArray *columns = [self columnsWithoutPrimaryKey];
    for (int i = 0; i < [columns count]; i++) {
        [parameterList addObject:@"?"];
    }

    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) values(%@)", [[self class] tableName], [columns componentsJoinedByString:@", "], [parameterList componentsJoinedByString:@","]];
    [self insertWithSql:sql withValues:[self propertyValues]];
}

- (void)insertWithSql:(NSString *)sql withColumns:(NSArray *)columns
{
    NSMutableArray *values = [[NSMutableArray alloc] init];
    for (NSString *column in columns) {
        id value = [self valueForKey:column];
        if (value)
            [values addObject:value];
        else if ([column isEqualToString:@"createdAt"])
            [values addObject:[NSDate date]];
        else
            [values addObject:[NSNull null]];
    }

    [[self database] executeUpdate:sql withArgumentsInArray:values];
    _savedInDatabase = YES;
    _primaryKey = [[self database] lastInsertRowId];
}

- (void)insertWithSql:(NSString *)sql withValues:(NSArray *)values
{
    [[self database] executeUpdate:sql withArgumentsInArray:values];
    _savedInDatabase = YES;
    _primaryKey = [[self database] lastInsertRowId];
}

- (void)update
{
    NSString *setValues = [[[self columnsWithoutPrimaryKey] componentsJoinedByString:@" = ?, "] stringByAppendingString:@" = ?"];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE primaryKey = ?", [[self class] tableName], setValues];
    NSArray  *parameters = [[self propertyValues] arrayByAddingObject:@(_primaryKey)];
    [[self database] executeUpdate:sql withArgumentsInArray:parameters];
    _savedInDatabase = YES;
}

- (void)updateWithColumns:(NSArray *)columns
{
    NSString *setValues = [[columns componentsJoinedByString:@" = ?, "] stringByAppendingString:@" = ?"];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE primaryKey = ?", [[self class] tableName], setValues];
    NSArray  *parameters = [[self propertyValuesWithColumns:columns] arrayByAddingObject:@(_primaryKey)];
    [[self database] executeUpdate:sql withArgumentsInArray:parameters];
    _savedInDatabase = YES;
}

- (void)delete
{
    [[self class] assertDatabaseExists];
    if (!_savedInDatabase) {
        return ;
    }
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE primaryKey = ?", [[self class] tableName]];
    [[self database] executeUpdate:sql withArgumentsInArray:@[@(_primaryKey)]];
    _savedInDatabase = NO;
    _primaryKey = 0;
}

+ (void)deleteWithCondition:(NSString *)condition withParameters:(NSArray *)parameters
{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", [[self class] tableName], condition];
    [[self database] executeUpdate:sql withArgumentsInArray:parameters];
}

+ (void)deleteAll
{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@", [self tableName]];
    [[self database] executeUpdate:sql];
}

#pragma mark - validate

- (BOOL)valid
{
    return YES;
}

@end