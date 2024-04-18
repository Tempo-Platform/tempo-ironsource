// General constants in use throughout app

public struct Constants {
    
    public static let SDK_VERSIONS = "1.4.1-rc.18"
    static let NO_FILL = "NO_FILL"
    static let OK = "OK"
    static let UNDEF = "UNDEFINED"
    static let ZERO_AD_ID = "00000000-0000-0000-0000-000000000000"
    static let TEMP_GEO_US = "US"
    
    struct Backup {
        static let METRIC_BACKUP_FOLDER = "metricJsons"
        static let METRIC_BACKUP_APPEND = ".tempo"
        static let LOC_BACKUP_REF = "locationData"
        static let MAX_BACKUPS: Int = 100
        static let EXPIRY_DAYS: Int = 7
    }
    
    struct JS {
        static let JS_FORCE_PLAY = "var video = document.getElementById('video'); if (video) { video.play(); void(0)}"
        static let LOCK_SCALE_SOURCE = "var meta = document.createElement('meta');" +
        "meta.name = 'viewport';" +
        "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
        "var head = document.getElementsByTagName('head')[0];" +
        "head.appendChild(meta);"
    }
    
    struct Web {
        static let METRICS_URL_PROD = "https://metric-api.tempoplatform.com/metrics" // PROD
        static let ADS_API_URL_PROD = "https://ads-api.tempoplatform.com/ad" // PROD
        static let ADS_DOM_URL_PROD = "https://ads.tempoplatform.com" // PROD
        static let METRICS_URL_DEV = "https://metric-api.dev.tempoplatform.com/metrics" // DEV
        static let ADS_API_URL_DEV = "https://ads-api.dev.tempoplatform.com/ad" // DEV
        static let ADS_DOM_URL_DEV = "https://development--tempo-html-ads.netlify.app" // DEV
        static let ADS_DOM_PREFIX_URL_PREVIEW = "https://deploy-preview-" // DEPLOY PREVIEW
        static let ADS_DOM_APPENDIX_URL_PREVIEW = "--tempo-html-ads.netlify.app/" // DEPLOY PREVIEW
        static let URL_INT = "interstitial"
        static let URL_REW = "campaign"
        static let HTTP_METHOD_POST = "POST"
        static let HEADER_METRIC_TIME = "X-Timestamp"
        static let HEADER_CONTENT_TYPE = "Content-Type"
        static let HEADER_ACCEPT = "Accept"
        static let APPLICATION_JSON = "application/json"
    }
    
    struct URL {
        static let UUID = "uuid"
        static let AD_ID = "ad_id"
        static let APP_ID = "app_id"
        static let CPM_FLOOR = "cpm_floor"
        static let LOCATION = "location"
        static let IS_INTERSTITIAL = "is_interstitial"
        static let SDK_VERSION = "sdk_version"
        static let ADAPTER_VERSION = "adapter_version"
        static let ADAPTER_TYPE = "adapter_type"
        
        static let LOC_COUNTRY_CODE = "country_code"
        static let LOC_POSTAL_CODE = "postal_code"
        static let LOC_ADMIN_AREA = "admin_area"
        static let LOC_SUB_ADMIN_AREA = "sub_admin_area"
        static let LOC_LOCALITY = "locality"
        static let LOC_SUB_LOCALITY = "locality"
    }
    
    struct MetricType {
        static let LOAD_REQUEST = "AD_LOAD_REQUEST"
        static let CUST_LOAD_REQUEST = "CUSTOM_AD_LOAD_REQUEST"
        static let SHOW = "AD_SHOW"
        static let SHOW_FAIL = "AD_SHOW_FAIL"
        static let LOAD_FAILED = "AD_LOAD_FAIL"
        static let LOAD_SUCCESS = "AD_LOAD_SUCCESS"
        static let CLOSE_AD = "TEMPO_CLOSE_AD"
        static let ASSETS_LOADED = "TEMPO_ASSETS_LOADED"
        static let VIDEO_LOADED = "TEMPO_VIDEO_LOADED"
        static let IMAGES_LOADED = "TEMPO_IMAGES_LOADED"
        static let TIMER_COMPLETED = "TIMER_COMPLETED"
        static let METRIC_OUTPUT_TYPES = [ASSETS_LOADED, VIDEO_LOADED, TIMER_COMPLETED, IMAGES_LOADED]
        static let METRIC_SEND_NOW = [SHOW, LOAD_REQUEST, TIMER_COMPLETED]
    }
    
    public enum LocationConsent: String {
        case NONE
        case GENERAL
        case PRECISE
    }
    
    // Testable variables
    public static var isProd = false
    public static var isTesting = true
    
}
