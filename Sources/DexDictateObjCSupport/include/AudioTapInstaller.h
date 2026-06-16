#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for failures captured while bridging AVAudioEngine tap operations.
extern NSString * const DDAudioTapInstallerErrorDomain;

/// `userInfo` key whose value is the caught `NSException`'s `name` (an `NSString`).
extern NSString * const DDAudioTapInstallerExceptionNameKey;

/// Error codes used in `DDAudioTapInstallerErrorDomain`.
typedef NS_ENUM(NSInteger, DDAudioTapInstallerErrorCode) {
    DDAudioTapInstallerErrorInstallFailed = 1,
    DDAudioTapInstallerErrorRemoveFailed = 2,
};

/// Bridges `-[AVAudioNode installTapOnBus:bufferSize:format:block:]` and
/// `-[AVAudioNode removeTapOnBus:]` through Objective-C `@try/@catch`.
///
/// Those AVFoundation methods raise an Objective-C `NSException` — not an
/// `NSError` — when an internal precondition fails (for example: a tap is
/// already installed on the bus, or the input node's hardware format is read
/// as 0 Hz / 0 channels at install time because the audio route changed). Swift
/// `do/catch` cannot intercept an `NSException`, so it reaches the uncaught
/// exception handler and calls `abort()`, terminating the process with SIGABRT.
///
/// These wrappers convert the `NSException` into an `NSError`, which the Swift
/// importer surfaces as a throwing function. The exception then becomes a
/// recoverable error on `com.dexdictate.audioEngine` instead of a crash.
@interface DDAudioTapInstaller : NSObject

/// Installs a tap on `node`, catching any `NSException` raised by AVFoundation.
/// Returns `YES` on success. On failure, returns `NO` and (if `error` is
/// non-NULL) populates `*error` with the exception name and reason.
+ (BOOL)installTapOnNode:(AVAudioNode *)node
                     bus:(AVAudioNodeBus)bus
              bufferSize:(AVAudioFrameCount)bufferSize
                  format:(nullable AVAudioFormat *)format
                   block:(AVAudioNodeTapBlock)block
                   error:(NSError * _Nullable * _Nullable)error;

/// Removes the tap on `node`'s bus, catching any `NSException` raised by
/// AVFoundation. Returns `YES` on success, `NO` (and populates `*error`) on a
/// caught exception.
+ (BOOL)removeTapOnNode:(AVAudioNode *)node
                    bus:(AVAudioNodeBus)bus
                  error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
