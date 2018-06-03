//
//  DSWalletViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletViewController.h"
#import "NSManagedObject+Sugar.h"
#import "DSWalletTableViewCell.h"
#import <DashSync/DashSync.h>
#import "DSWalletInputPhraseViewController.h"

@interface DSWalletViewController ()

@property (nonatomic,strong) id<NSObject> chainWalletObserver;

@end

@implementation DSWalletViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainWalletObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletAddedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self.tableView reloadData];
                                                       }];
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Put this back in when we have multi wallet feature

//- (NSFetchedResultsController *)fetchedResultsController {
//
//    if (_fetchedResultsController != nil) {
//        return _fetchedResultsController;
//    }
//    NSManagedObjectContext * context = [NSManagedObject context];
//    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
//    NSEntityDescription *entity = [NSEntityDescription
//                                   entityForName:@"DSWalletEntity" inManagedObjectContext:context];
//    [fetchRequest setEntity:entity];
//
//    NSSortDescriptor *sort = [[NSSortDescriptor alloc]
//                              initWithKey:@"created" ascending:NO];
//    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
//
//    [fetchRequest setFetchBatchSize:20];
//
//    NSFetchedResultsController *theFetchedResultsController =
//    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
//                                        managedObjectContext:context sectionNameKeyPath:nil
//                                                   cacheName:nil];
//    self.fetchedResultsController = theFetchedResultsController;
//    _fetchedResultsController.delegate = self;
//
//    return _fetchedResultsController;
//
//}
//
//- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
//    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
//    [self.tableView beginUpdates];
//}
//
//
//- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
//
//    UITableView *tableView = self.tableView;
//
//    switch(type) {
//
//        case NSFetchedResultsChangeInsert:
//            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
//            break;
//
//        case NSFetchedResultsChangeDelete:
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
//            break;
//
//        case NSFetchedResultsChangeUpdate:
//            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
//            break;
//
//        case NSFetchedResultsChangeMove:
//            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
//            break;
//    }
//}
//
//
//- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
//    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
//    [self.tableView endUpdates];
//}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return [self.chain.wallets count];
    else return [self.chain.standaloneDerivationPaths count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Wallets";
            break;
        case 1:
            return @"Standalone derivation paths";
            break;
        default:
            return @"";
            break;
    };
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = nil;
    switch (indexPath.section) {
        case 0:
            cellIdentifier = @"WalletCell";
            break;
        case 1:
            cellIdentifier = @"StandaloneDerivationPathCell";
            break;
        default:
            break;
    }
    
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
    @autoreleasepool {
        DSWalletTableViewCell * walletCell = (DSWalletTableViewCell*)cell;
        DSWallet * wallet = [[self.chain wallets] objectAtIndex:indexPath.row];
        NSString * passphrase = [wallet seedPhraseIfAuthenticated];
        NSArray * components = [passphrase componentsSeparatedByString:@" "];
        NSMutableArray * lines = [NSMutableArray array];
        for (int i = 0;i<[components count];i+=4) {
            [lines addObject:[[components subarrayWithRange:NSMakeRange(i, 4)] componentsJoinedByString:@" "]];
        }
        
        walletCell.passphraseLabel.text = [lines componentsJoinedByString:@"\n"];
        DSAccount * account0 = [wallet accountWithNumber:0];
        walletCell.xPublicKeyLabel.text = [[account0 bip44DerivationPath] serializedExtendedPublicKey];
    }
    } else {
        DSWalletTableViewCell * walletCell = (DSWalletTableViewCell*)cell;
        DSDerivationPath * derivationPath = [[self.chain standaloneDerivationPaths] objectAtIndex:indexPath.row];
        walletCell.xPublicKeyLabel.text = [derivationPath serializedExtendedPublicKey];
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return 200;
    return 50;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return TRUE;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddWalletSegue"]) {
        DSWalletInputPhraseViewController * walletInputViewController = (DSWalletInputPhraseViewController*)segue.destinationViewController;
        walletInputViewController.chain = self.chain;
    }
}

@end
