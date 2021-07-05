//
//  MainVC.m
//  Advanced-Example
//

#import "MainVC.h"

#import <KSCrash/KSCrash.h>
#import "AppDelegate.h"
#import <KSCrash/KSCrashInstallation.h>
#import <objc/runtime.h>

/**
 * Some sensitive info that should not be printed out at any time.
 *
 * If you have Objective-C introspection turned on, it would normally
 * introspect this class, unless you add it to the list of
 * "do not introspect classes" in KSCrash. We do precisely this in 
 * -[AppDelegate configureAdvancedSettings]
 */
@interface SensitiveInfo: NSObject

@property(nonatomic, readwrite, strong) NSString* password;

@end

@implementation SensitiveInfo

@end



@interface MainVC ()

@property(nonatomic, readwrite, strong) SensitiveInfo* info;
@property (nonatomic, strong) NSArray *crashTestArray;

@property (nonatomic, copy) void(^block)(void);

@property (nonatomic, weak) UIView *weakView;
@property (nonatomic, unsafe_unretained) UIView *unsafeView;
@property (nonatomic, assign) UIView *assignView;

@end

@implementation MainVC

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder]))
    {
        // This info could be leaked during introspection unless you tell KSCrash to ignore it.
        // See -[AppDelegate configureAdvancedSettings] for more info.
        self.info = [SensitiveInfo new];
        self.info.password = @"it's a secret!";
    }
    return self;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [UIView new];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    self.crashTestArray = @[
        @"onReportedCrash:",
        @"crashUnrecognizedSelector",
        @"crashKVC1",
        @"crashKVC2",
        @"crashKVC3",
        @"crashKVO1",
        @"crashKVO2",
        @"crashExcBadAccess1",
        @"crashExcBadAccess2",
        @"crashExcBadAccess3",
        @"crashCollection1",
        @"crashCollection2",
        @"crashCollection3",
        @"crashThread1",
        @"crashThread2",
        @"crashThread3",
        @"crashThread4",
        @"crashNSNull",
    ];

//    UIButton * reportExceptionBtn = [[UIButton alloc] initWithFrame:CGRectMake(60, 100, 200, 50)];
//    reportExceptionBtn.backgroundColor = [UIColor orangeColor];
//    [reportExceptionBtn setTitle:@"Report Exception" forState:UIControlStateNormal];
//    [reportExceptionBtn setTitle:@"Report Exception" forState:UIControlStateHighlighted];
//    [reportExceptionBtn addTarget:self action:@selector(onReportedCrash:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:reportExceptionBtn];
//
//    UIButton * reportUncaughtExceptionBtn = [[UIButton alloc] initWithFrame:CGRectMake(60, 200, 200, 50)];
//    reportUncaughtExceptionBtn.backgroundColor = [UIColor greenColor];
//    [reportUncaughtExceptionBtn setTitle:@"Uncaught Exception" forState:UIControlStateNormal];
//    [reportUncaughtExceptionBtn setTitle:@"Uncaught Exception" forState:UIControlStateHighlighted];
//    [reportUncaughtExceptionBtn addTarget:self action:@selector(crashCollection3) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:reportUncaughtExceptionBtn];
    
    CGFloat y = 0;
    
    for (NSString *sel in self.crashTestArray) {
        y += 100;
        UIButton * btn = [[UIButton alloc] initWithFrame:CGRectMake(60, y, 200, 50)];
        btn.backgroundColor = [UIColor orangeColor];
        [btn setTitle:sel forState:UIControlStateNormal];
        [btn setTitle:sel forState:UIControlStateHighlighted];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        [btn addTarget:self action:NSSelectorFromString(sel) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}

- (void) onReportedCrash:(id)sender {
    NSException* ex = [NSException exceptionWithName:@"testing exception name" reason:@"testing exception reason" userInfo:@{@"testing exception key":@"testing exception value"}];
    [KSCrash sharedInstance].currentSnapshotUserReportedExceptionHandler(ex);
    [KSCrash sharedInstance].monitoring = KSCrashMonitorTypeProductionSafe;
    [self sendAllExceptions];
}

- (void) sendAllExceptions {
    AppDelegate* appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;

    [appDelegate.crashInstallation sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        if(completed) {
            NSLog(@"\n****Sent %lu reports", (unsigned long)[filteredReports count]);
            NSLog(@"\n%@", filteredReports);
            //        [[KSCrash sharedInstance] deleteAllReports];
        } else {
            NSLog(@"Failed to send reports: %@", error);
        }
    }];
}

- (IBAction) onCrash:(__unused id) sender
{
    char* invalid = (char*)-1;
    *invalid = 1;
}

/// 找不到方法的实现
- (void)crashUnrecognizedSelector {
    [self performSelector:@selector(aaa:)];
}

/// 通过不存在的key赋值
- (void)crashKVC1 {
    [self setValue:@"" forKey:@"123"];
}

/// key设置为nil
- (void)crashKVC2 {
    [self setValue:@"" forKey:nil];
}

/// 通过不存在的key取值
- (void)crashKVC3 {
    [self valueForKey:@"123"];
}

/// 没有实现observeValueForKeyPath:ofObject:changecontext:导致crash
- (void)crashKVO1 {
    SensitiveInfo* obj = [[SensitiveInfo alloc] init];
    [obj addObserver:self
              forKeyPath:@"password"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    obj.password = @"";
}

/// 重复移除观察者
- (void)crashKVO2 {
    SensitiveInfo* obj = [[SensitiveInfo alloc] init];
    [obj addObserver:self
              forKeyPath:@"password"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    [obj removeObserver:self forKeyPath:@"password"];
    [obj removeObserver:self forKeyPath:@"password"];
}

/// 悬挂指针：访问没有实现的Block
- (void)crashExcBadAccess1 {
    self.block();
}

/// 悬挂指针：对象没有被初始化
- (void)crashExcBadAccess2 {
    UIView *view = [UIView alloc];
    view.backgroundColor = [UIColor redColor];
    [self.view addSubview:view];
}

/// 野指针
- (void)crashExcBadAccess3 {
    {
        UIView *view = [[UIView alloc]init];
        view.backgroundColor = [UIColor redColor];
        self.weakView = view;
        self.unsafeView = view;
        self.assignView = view;
        self.associatedView = view;
    }
    
    //addSubview:nil时不会crash
    //以下崩溃都是Thread 1: EXC_BAD_ACCESS (code=EXC_I386_GPFLT)
    //不会crash, arc下view释放后，weakView会置为nil，因此这行代码不会崩溃
    [self.view addSubview:self.weakView];
    //野指针场景一: unsafeunreatin修饰的对象释放后，不会自动置为nil，变成野指针，因此崩溃
    [self.view addSubview:self.unsafeView];
    //野指针场景二：应该使用strong/weak修饰的对象，却错误的使用了assign，释放后不会置为nil
    [self.view addSubview:self.assignView];
    //野指针场景三：给类添加关联变量时，类似场景二，应该使用OBJC_ASSOCIATION_RETAIN,却错误的使用了OBJC_ASSOCIATION_ASSIGN
    [self.view addSubview:self.associatedView];
}

- (void)setAssociatedView:(UIView *)associatedView {
    /*
     self: 关联对象的类
     key:  要保证全局唯一，key与关联的对象是一一对应关系，必须全局唯一，通常用@selector(methodName)做为key
     value: 要关联的对象
     policy:关联策略
     OBJC_ASSOCIATION_COPY: 相当于@property(atomic,copy)
     OBJC_ASSOCIATION_COPY_NONATOMIC: 相当于@property(nonatomic, copy)
     OBJC_ASSOCIATION_ASSIGN: 相当于@property(assign)
     OBJC_ASSOCIATION_RETAIN: 相当于@property(atomic, strong)
     OBJC_ASSOCIATION_RETAIN_NONATOMIC: 相当于@property(nonatomic, strong)
     */
    objc_setAssociatedObject(self, @selector(associatedView), associatedView, OBJC_ASSOCIATION_ASSIGN);
    //objc_setAssociatedObject(self, @selector(associatedView), associatedView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)associatedView {
    return objc_getAssociatedObject(self, _cmd);
}

/// 数组越界
- (void)crashCollection1 {
    NSMutableArray *array = [NSMutableArray arrayWithObjects:@1, @2, @3, nil];
    NSNumber *number = [array objectAtIndex:3];
    NSLog(@"number: %@", number);
}

/// 向集合中插入nil元素
- (void)crashCollection2 {
    NSMutableArray *array = [NSMutableArray arrayWithObjects:@1, @2, @3, nil];
    [array addObject:nil];
}

/// 一边遍历数组，一边移除数组中元素
- (void)crashCollection3 {
    NSMutableArray *array = [NSMutableArray arrayWithObjects:@1, @2, @3, nil];
    for (NSNumber *b in array) {
        [array removeObject:b];
    }
}

/// dispatch_group_leave 比dispatch_group_enter多
- (void)crashThread1 {
    //Thread 1: EXC_BAD_INSTRUCTION (code=EXC_I386_INVOP, subcode=0x0)
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_leave(group);
}

/// 子线程中刷新UI
- (void)crashThread2 {
    dispatch_queue_t queue = dispatch_queue_create("com.objc.c", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue , ^{
        NSLog(@"thread: %@", [NSThread currentThread]);
        self.view.backgroundColor = [UIColor yellowColor];
    });
}

/// 多个线程同时访问、释放同一对象
- (void)crashThread3 {
    //使用信号量后不会崩溃
    {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
        __block NSObject *obj = [[NSObject alloc] init];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (YES) {
                NSLog(@"dispatch_async -- 1");
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                obj = [[NSObject alloc] init];
                dispatch_semaphore_signal(semaphore);
            }
        });
        
        while (YES) {
            NSLog(@"dispatch_sync -- 2");
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            obj = [[NSObject alloc] init];
            dispatch_semaphore_signal(semaphore);
        }

    }
    
    //不使用信号量，多线程同时释放对象导致崩溃
    {
        __block NSObject *obj = [[NSObject alloc] init];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (YES) {
                NSLog(@"dispatch_async -- 3");
                obj = [[NSObject alloc] init];
            }
        });
        
        while (YES) {
            NSLog(@"dispatch_sync -- 4");
            obj = [[NSObject alloc] init];
        }
    }
}

/// 多线程下访问数据：NSMutableArray、NSMutaleDictionary， NSCache是线程安全的
- (void)crashThread4 {
    dispatch_queue_t queue1 = dispatch_queue_create("com.objc.c1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("com.objc.c2", DISPATCH_QUEUE_SERIAL);
    NSMutableArray *array = [NSMutableArray array];
    dispatch_async(queue1, ^{
        NSLog(@"queue1: %@", [NSThread currentThread]);
        while (YES) {
            if (array.count < 10) {
                [array addObject:@(array.count)];
            } else {
                [array removeAllObjects];
            }
        }
    });
    
    dispatch_async(queue2, ^{
        NSLog(@"queue2: %@", [NSThread currentThread]);
        while (YES) {
            /*
             数组地址已经改变
             reason: '*** Collection <__NSArrayM: 0x6000020319b0> was mutated while being enumerated.'
             */
            for (NSNumber *number in array) {
                NSLog(@"queue2 forin array %@", number);
            }
            
            /*
             reason: '*** Collection <__NSArrayM: 0x600002072d60> was mutated while being enumerated.'
             */
            NSArray *array2 = array;
            for (NSNumber *number in array2) {
                NSLog(@"queue2 forin array2 %@", number);
            }
            
            /*
             在[NSArray copy]的时候，copy方法内部调用`initWithArray:range:copyItem:`时
             NSArray被另一个线程清空，range不一致导致跑出异常
             reason: '*** -[__NSArrayM getObjects:range:]: range {0, 2} extends beyond bounds for empty array'
             复制过程中数组内对象被其它线程释放，导致访问僵尸对象
             Thread 4: EXC_BAD_ACCESS (code=1, address=0x754822c49fc0)
             */
            NSArray *array3 = [array copy];
            for (NSNumber *number in array3) {
                NSLog(@"queue2 forin array3 %@", number);
            }
            
            /*
             复制过程中数组内对象被其它线程释放，导致访问僵尸对象
             Thread 12: EXC_BAD_ACCESS (code=EXC_I386_GPFLT)
             */
            NSArray *array4 = [array mutableCopy];
            for (NSNumber *number in array4) {
                NSLog(@"queue2 forin array4 %@", number);
            }
        }
    });
}

/// 后台返回NSNull导致崩溃，多见于JAVA后台返回
- (void)crashNSNull {
    /*
     reason: '-[NSNull integerValue]: unrecognized selector sent to instance 0x7fff8004b700'
     NULL: 用于基本数据类型，如NSInteger
     nil : 用于OC对象
     Nil : 用于Class类型对象的赋值(类是元类的实例，也是对象)
     NSNull: 用于OC对象的占位，一般会做为集合中的占位元素，给NSNull对象发消息会crash，后台给我们返回的就是NSNull对象
     */
    NSNull *null = [[NSNull alloc] init];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:null forKey:@"key"];
    NSInteger integer = [[dict valueForKey:@"key"] integerValue];
}

@end


