#include <jni.h>
#include "focus_audio_runtime.h"
namespace {
JavaVM* vm = nullptr;
jclass bridge = nullptr;
jmethodID receive = nullptr;
void Event(int kind, int64_t owner, int64_t generation, int64_t epoch) {
  if (!vm || !bridge || !receive) return;
  JNIEnv* env = nullptr;
  const bool attach = vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK;
  if (attach && vm->AttachCurrentThread(&env, nullptr) != JNI_OK) return;
  env->CallStaticVoidMethod(bridge, receive, kind, static_cast<jlong>(owner),
      static_cast<jlong>(generation), static_cast<jlong>(epoch));
  if (env->ExceptionCheck()) env->ExceptionClear();
  if (attach) vm->DetachCurrentThread();
}
}
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* value, void*) {
  vm = value; return JNI_VERSION_1_6;
}
extern "C" JNIEXPORT void JNICALL
Java_dev_poma_poma_PomaAudioNative_attach(JNIEnv* env, jclass type) {
  if (bridge) env->DeleteGlobalRef(bridge);
  bridge = static_cast<jclass>(env->NewGlobalRef(type));
  receive = env->GetStaticMethodID(type, "event", "(IJJJ)V");
  pomaMobileSetEvent(Event);
}
#define QUERY(name, expression) extern "C" JNIEXPORT jlong JNICALL \
Java_dev_poma_poma_PomaAudioNative_##name(JNIEnv*, jclass) { return expression; }
QUERY(owner, pomaMobileOwner())
QUERY(generation, pomaMobileGeneration())
QUERY(epoch, pomaMobileEpoch())
QUERY(now, pomaMobileNow())
QUERY(busy, pomaMobileBusy())
QUERY(playing, pomaMobilePlaying())
extern "C" JNIEXPORT void JNICALL
Java_dev_poma_poma_PomaAudioNative_interrupt(JNIEnv*, jclass, jint kind) { pomaMobileInterrupt(kind); }
extern "C" JNIEXPORT void JNICALL
Java_dev_poma_poma_PomaAudioNative_reconcile(JNIEnv*, jclass) { pomaMobileReconcile(); }
extern "C" JNIEXPORT jlong JNICALL
Java_dev_poma_poma_PomaAudioNative_prepare(JNIEnv* env, jclass, jlong owner,
    jlong generation, jlong epoch, jlong deadline, jint sound, jbyteArray data) {
  if (!data || env->GetArrayLength(data) > 4 * 1024 * 1024) return 0;
  const auto size = env->GetArrayLength(data);
  auto* bytes = env->GetByteArrayElements(data, nullptr);
  if (!bytes) return 0;
  const auto result = pomaMobilePrepare(owner, generation, epoch, deadline, sound,
      reinterpret_cast<unsigned char*>(bytes), size);
  env->ReleaseByteArrayElements(data, bytes, JNI_ABORT);
  return result;
}
extern "C" JNIEXPORT jint JNICALL
Java_dev_poma_poma_PomaAudioNative_start(JNIEnv*, jclass, jlong owner, jlong source,
    jlong generation, jlong epoch, jlong deadline, jdouble gain) {
  return pomaMobileStart(owner, source, generation, epoch, deadline, static_cast<float>(gain));
}
extern "C" JNIEXPORT void JNICALL
Java_dev_poma_poma_PomaAudioNative_release(JNIEnv*, jclass, jlong owner, jlong source) {
  pomaMobileRelease(owner, source);
}
