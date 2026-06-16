#import "AudioTapInstaller.h"

NSString * const DDAudioTapInstallerErrorDomain = @"com.dexdictate.audioTapInstaller";
NSString * const DDAudioTapInstallerExceptionNameKey = @"DDAudioTapInstallerExceptionName";

@implementation DDAudioTapInstaller

+ (NSError *)errorFromException:(NSException *)exception
                           code:(DDAudioTapInstallerErrorCode)code {
    NSString *name = exception.name ?: @"NSException";
    NSString *reason = exception.reason ?: @"unknown reason";

    NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] =
        [NSString stringWithFormat:@"%@: %@", name, reason];
    userInfo[DDAudioTapInstallerExceptionNameKey] = name;

    return [NSError errorWithDomain:DDAudioTapInstallerErrorDomain
                               code:code
                           userInfo:userInfo];
}

+ (BOOL)installTapOnNode:(AVAudioNode *)node
                     bus:(AVAudioNodeBus)bus
              bufferSize:(AVAudioFrameCount)bufferSize
                  format:(nullable AVAudioFormat *)format
                   block:(AVAudioNodeTapBlock)block
                   error:(NSError * _Nullable * _Nullable)error {
    @try {
        [node installTapOnBus:bus bufferSize:bufferSize format:format block:block];
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = [self errorFromException:exception
                                         code:DDAudioTapInstallerErrorInstallFailed];
        }
        return NO;
    }
}

+ (BOOL)removeTapOnNode:(AVAudioNode *)node
                    bus:(AVAudioNodeBus)bus
                  error:(NSError * _Nullable * _Nullable)error {
    @try {
        [node removeTapOnBus:bus];
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = [self errorFromException:exception
                                         code:DDAudioTapInstallerErrorRemoveFailed];
        }
        return NO;
    }
}

@end
