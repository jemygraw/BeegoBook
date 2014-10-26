beego的日志模块目前默认支持以下几种记录方式。

|记录方式|适配器名称|描述|
|---|-----------|-----|
|终端输出（Console）|console|这种方式一般用在开发环境下面，方便调试。|
|本地文件（File）|file|这种方式一般用来保存常规日志，为生产环境中常用的方式。|
|网络方式（Network）|network|这种方式可以用来将日志发送到指定服务器，一般可以用来根据日志触发事件等。|
|发送邮件（Email）|email|这种方式一般是将生产环境下比较重要的日志发送给相应的管理人员，以便及时发现和解决问题。|

**选择哪种日记记录方式完全根据实际的需求，不一定拘泥于哪种形式。当然也不要滥用一些比较敏感的方式，比如常规的日志一般不要用邮件发送给管理人员，否则我保证他会剁了你的。**

**这些不同的日志记录方式是可以共存的，实际生产情况下，可能需要你将本地文件记录方式和发送邮件的方式结合起来使用，一切看实际需求。**

日志是分等级的，目前beego的日志模块采用了`RFC5424`推荐的日志等级分类，而原来的一些非标准的等级可能在未来的版本中删除。
日志等级定义在`github.com/astaxie/beego/logs/log.go`里面。

```go
// REC5424 的日志等级分类
const (
	LevelEmergency = iota
	LevelAlert
	LevelCritical
	LevelError
	LevelWarning
	LevelNotice
	LevelInformational
	LevelDebug
)

// 为了向后兼容而保留的日志等级分类
// 将在1.5.0版本中删除
const (
	LevelInfo  = LevelInformational
	LevelTrace = LevelDebug
	LevelWarn  = LevelWarning
)
```

beego中之所以可以并存多个日志记录方式，完全是由`BeeLogger`决定的，该结构体定义在`github.com/astaxie/beego/logs/log.go`里面。

```go
// BeeLogger是beego应用中的默认logger记录器
// 它可以包含多个logger记录方式
type BeeLogger struct {
	lock                sync.Mutex
	level               int
	enableFuncCallDepth bool
	loggerFuncCallDepth int
	msg                 chan *logMsg
	outputs             map[string]LoggerInterface
}
```
看到`outputs map[string]LoggerInterface`的定义了么，这里保存着多个不同的日志记录方式。

好了，我们再看一下beego中日志模块的相关方法：

|方法|原型|描述|
|----|-----|----|
|NewLogger|func NewLogger(channellen int64) *BeeLogger|创建一个新的日志记录器，参数`channlelen`为日志缓冲区的大小。缓冲区满，日志会写入相应记录方式对应的地方。|
|SetLogger|func (bl *BeeLogger) SetLogger(adaptername string, config string) error|设置日志记录方式，可以多次调用该函数，同时设置多个不同的日志记录方式。参数`adaptername`为日志记录方式名称，默认可选为`console`，`file`，`network`，`email`。参数`config`为一个`json字符串`，该字符串里面包含了该日志记录方式相关的配置信息。|
|DelLogger|func (bl *BeeLogger) DelLogger(adaptername string) error|从日志记录器里面删除一种日志记录方式，该方式由参数`adaptername`指定，可选值同`SetLogger`。|
|SetLevel|func (bl *BeeLogger) SetLevel(l int) |设置日志记录器的日志级别，可选值上面已经介绍过了。可以使用`logs.LevelAlert`这种方式来提供参数。|
|SetLogFuncCallDepth|func (bl *BeeLogger) SetLogFuncCallDepth(d int)|设置日志函数调用深度。|
|EnableFuncCallDepth|func (bl *BeeLogger) EnableFuncCallDepth(b bool)|设置是否启用日志函数调用深度功能。|
|Emergency|func (bl *BeeLogger) Emergency(format string, v ...interface{}) |按照指定格式，输出Emergency级别的日志信息。|
|Alert|func (bl *BeeLogger) Alert(format string, v ...interface{}) |按照指定格式，输出Alert级别的日志信息。|
|Critical|func (bl *BeeLogger) Critical(format string, v ...interface{})|按照指定格式，输出Critical级别的日志信息。|
|Error|func (bl *BeeLogger) Error(format string, v ...interface{})|按照指定格式，输出Error级别的日志信息。|
|Warning|func (bl *BeeLogger) Warning(format string, v ...interface{}) |按照指定格式，输出Warning级别的日志信息。|
|Notice|func (bl *BeeLogger) Notice(format string, v ...interface{})|按照指定格式，输出Notice级别的日志信息。|
|Informational|func (bl *BeeLogger) Informational(format string, v ...interface{})|按照指定格式，输出Informational级别的日志信息。|
|Debug|func (bl *BeeLogger) Debug(format string, v ...interface{}) |按照指定格式，输出Debug级别的日志信息。|
|Warn|func (bl *BeeLogger) Warn(format string, v ...interface{})|已废弃。将在1.5.0版本移除。|
|Info|func (bl *BeeLogger) Info(format string, v ...interface{})|已废弃。将在1.5.0版本移除。|
|Trace|func (bl *BeeLogger) Trace(format string, v ...interface{})|已废弃。将在1.5.0版本移除。|
|Flush|func (bl *BeeLogger) Flush()|将日志缓冲区信息写入相应日志记录方式对应的地方。|
|Close|func (bl *BeeLogger) Close()|关闭日志记录器，将缓冲区信息写出，然后销毁所有的日志记录方式。|

上面的方法是`BeeLogger`相关的方法。一般在我们的日志应用中使用最为频繁。

另外还有一个方法，用来注册不同的日志记录方式。

```go
func Register(name string, log loggerType)
```
该函数有两个参数，第一个name为日志记录方式名称，也可以叫做adaptername，另外一个参数是一个接口类型参数，任何实现了该接口方法的结构体类型都可以注册为日志记录方式。

我们可以看下`loggerType`(位于`github.com/astaxie/beego/logs/log.go`)的初始化代码：

```go
type loggerType func() LoggerInterface

// LoggerInterface 定义了日志记录方式接口
type LoggerInterface interface {
	Init(config string) error
	WriteMsg(msg string, level int) error
	Destroy()
	Flush()
}
```
我们可以在beego默认提供的4种日志记录方式的初始化函数`init()`里面看到这样的定义。

**github.com/astaxie/beego/logs/console.go**

```go
func init() {
	Register("console", NewConsole)
}
```
**github.com/astaxie/beego/logs/file.go**

```go
func init() {
	Register("file", NewFileWriter)
}
```
**github.com/astaxie/beego/logs/conn.go**

```go
func init() {
	Register("conn", NewConn)
}
```
**github.com/astaxie/beego/logs/smtp.go**

```go
func init() {
	Register("smtp", NewSmtpWriter)
}
```

这也就是说，你完全可以实现一种新的日志记录方式，只要实现了`LoggerInterface`接口所定义的全部方法，然后在初始化函数中使用`Register()`函数注册一下就可以了。

好了，在接下来的文章中，我们将逐一介绍beego提供的4种日志记录方式的使用方法。
