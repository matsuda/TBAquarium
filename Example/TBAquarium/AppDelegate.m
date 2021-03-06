//
//  AppDelegate.m
//  TBAquarium
//
//  Created by Kosuke Matsuda on 2014/03/27.
//  Copyright (c) 2014年 matsuda. All rights reserved.
//

#import "AppDelegate.h"
#import <TBAquarium.h>
#import <NSString+TBAquarium.h>
#import "ExampleMigration.h"

static NSString * const kDBFileName = @"tbaquarium.db";

@interface AppDelegate ()
@property (strong, nonatomic) TBDatabase *database;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    [self prepareDatabase];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    NSArray *strings = @[@"history", @"knife", @"post", @"ox"];
    for (NSString *str in strings) {
        NSLog(@"%@ => %@", str, [str tb_pluralizeString]);
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self.database close];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [self.database open];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [self.database close];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareDatabase
{
    self.database = [TBDatabase databaseWithFileName:kDBFileName];
#if DEBUG
    //    self.database.traceExecution = YES;
#endif
    [self.database open];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMigrate:) name:TBMigrationDidMigrateNotification object:nil];
    // [ExampleMigration migrateWithDatabase:self.database];
    [ExampleMigration asyncMigrateWithDatabase:self.database];
}

- (void)didMigrate:(NSNotification *)notification
{
    NSLog(@"--------------- didMigrate -------------------");
    NSLog(@"result >>>>> %@", notification.userInfo[@"result"]);
}

@end
