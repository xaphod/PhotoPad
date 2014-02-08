//
//  SSCheckMark.h
//  PhotoPad
//
//  source: http://stackoverflow.com/questions/18977527/how-do-i-display-the-standard-checkmark-on-a-uicollectionviewcell
//

#import <UIKit/UIKit.h>

typedef NS_ENUM( NSUInteger, SSCheckMarkStyle )
{
    SSCheckMarkStyleOpenCircle,
    SSCheckMarkStyleGrayedOut
};

@interface SSCheckMark : UIView

@property (readwrite, nonatomic) bool checked;
@property (readwrite, nonatomic) SSCheckMarkStyle checkMarkStyle;

@end