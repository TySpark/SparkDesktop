#pragma once

#include <atomic>
#include <chrono>
#include <cstdint>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <vector>

namespace snowdesktop::http_security
{
bool IsAllowedRemoteIpLiteral(std::wstring_view address);
bool IsAllowedUrlForDomains(const std::wstring& url,
    const std::vector<std::string>& domains,
    bool allowAnyHttpOrHttpsUrl = false);
}

struct HttpRequestOptions
{
    std::wstring widgetId;
    std::wstring url;
    std::wstring method = L"GET";
    std::wstring headers;
    std::string body;
    int timeoutMs = 10000;
    int cacheSeconds = 0;
    std::vector<std::string> allowedDomains;
    bool allowAnyHttpOrHttpsUrl = false;
    // 非空时响应体流式写入该文件（替代内存缓冲），用于大文件下载。
    std::wstring bodyFilePath;
    // 允许跟随 302 重定向（GitHub 资产下载会重定向到 CDN）。
    bool allowRedirects = false;
    // 跳过 DNS pinning（强制解析固定 IP）。CDN（如 GitHub 资产下载）
    // 多节点且常与代理冲突，pinning 到单个 IP 会导致连接超时。
    bool skipPinning = false;
    // 可选的下载进度共享状态（发起方轮询显示进度）。
    std::shared_ptr<struct DownloadProgress> progress;
};

/// 下载进度（线程安全共享计数器）。
struct DownloadProgress
{
    std::atomic<long long> bytes{ 0 };
    std::atomic<long long> total{ 0 };  // 0 表示未知
};

struct HttpResponse
{
    int id = 0;
    std::wstring widgetId;
    int status = 0;
    std::string body;
    std::string error;
    bool fromCache = false;
};

class AsyncHttpService
{
public:
    AsyncHttpService() = default;
    ~AsyncHttpService();

    int Submit(HttpRequestOptions options);
    bool Cancel(const std::wstring& widgetId, int requestId);
    std::vector<HttpResponse> Drain();
    void CancelWidget(const std::wstring& widgetId);
    void Stop();

private:
    struct RequestState
    {
        std::wstring widgetId;
        std::jthread worker;
    };
    struct CacheEntry
    {
        HttpResponse response;
        std::chrono::steady_clock::time_point expires;
    };

    static HttpResponse Execute(int id, const HttpRequestOptions& options, std::stop_token token);
    void Complete(HttpResponse response);

    std::atomic<int> nextId_{ 1 };
    std::mutex mutex_;
    std::unordered_map<int, std::unique_ptr<RequestState>> requests_;
    std::deque<HttpResponse> completed_;
    std::unordered_map<std::wstring, CacheEntry> cache_;
};
