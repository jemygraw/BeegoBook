在深入讲解beego默认支持的四种日志记录方法之前，我们有必要看一下beego的logs模块的代码结构，这样我们就可以大致对这个模块有一个比较清晰的认识。然后再去讲解四种日志记录方法就很方便了。
首先我们看一下logs模块下的文件组织。在`github.com/astaxie/beego/logs`下面，有如下的一些文件：

|文件|描述|
|---|----|
|log.go|beego日志模块的框架性定义文件，包括日志等级分类，日志记录方式的公共接口，日志使用方式的接口等都在这个文件定义。这个文件里面的方法我们在（1）里面已经大部分介绍过了，我们本节里面主要探讨的是日志的写入方式。|
|conn.go|日志记录方式之网络输出方式的实现文件。|
|conn_test.go|conn.go的功能测试文件，其实也算是使用方式的例子。|
|console.go|日志记录方式之终端输出的实现文件。|
|console_test.go|console.go的功能测试文件，其实也算是使用方式的例子。|
|file.go|日志记录方式之文件输出的实现文件。|
|file_test.go|file.go的功能测试文件，其实也算是使用方式的例子。|
|smtp.go|日志记录方式之邮箱发送的实现文件。|
|smtp_test.go|smtp.go的功能测试文件，其实也算是使用方式的例子。|

简单来说，`log.go`定义了beego的logs模块的接口，而其他的文件则是定义了具体的日志记录方式的实现。

`log.go`的大部分方法我们在（1）里面已经简要介绍过了，这里我们回顾一些要点。

**NewLogger**

```go
func NewLogger(channellen int64) *BeeLogger {
	bl := new(BeeLogger)
	bl.level = LevelDebug
	bl.loggerFuncCallDepth = 2
	bl.msg = make(chan *logMsg, channellen)
	bl.outputs = make(map[string]LoggerInterface)
	go bl.startLogger()
	return bl
}
```

1. 该函数通过提供一个日志缓冲区大小来创建一个新的日志记录器即BeeLogger的实例对象;
2. 该函数创建的BeeLogger实例对象的默认日志级别为`LevelDebug`，日志调用深度为`2`;
3. 该函数调用的时候会同时创建一个日志缓冲区并初始化一个日志记录方式的map;
4. 该函数调用的时候会启动一个日志输出协程来将日志写出到每种日志记录方式对应的地方。

**startLogger**

```go
func (bl *BeeLogger) startLogger() {
	for {
		select {
		case bm := <-bl.msg:
			for _, l := range bl.outputs {
				l.WriteMsg(bm.msg, bm.level)
			}
		}
	}
}
```

1. 该函数在日志缓冲区不为空的时候读取日志并按照不同的日志输出方式输出。
2. 该函数是由上面的`NewLogger`调用的，以单独的协程运行。
3. 该函数因为是运行在单独的协程里面，所以在编写测试文件的时候要注意，要给予该协程运行的机会，即不要在协程还没有调度运行的时候，主函数已经退出了。
4. 注意该函数的日志输出方式是遍历BeeLogger所有的日志记录方式并逐个输出，这也就是说`WriteMsg`方法的实际执行内容是由每种实现了该方法的日志记录方式所决定的。

**writeMsg**

```go
func (bl *BeeLogger) writerMsg(loglevel int, msg string) error {
	if loglevel > bl.level {
		return nil
	}
	lm := new(logMsg)
	lm.level = loglevel
	if bl.enableFuncCallDepth {
		_, file, line, ok := runtime.Caller(bl.loggerFuncCallDepth)
		if ok {
			_, filename := path.Split(file)
			lm.msg = fmt.Sprintf("[%s:%d] %s", filename, line, msg)
		} else {
			lm.msg = msg
		}
	} else {
		lm.msg = msg
	}
	bl.msg <- lm
	return nil
}
```

1. 上面我们看过了`WriteMsg`方法，该方式是日志记录方式将日志写出的方法。但是这里的`writeMsg`方法却是将日志信息写入日志缓冲区的方法。
2. 该函数中，**首先验证框架级别的日志等级，这也决定了如果框架级别的日志等级如果高于每种日志记录方式的日志等级的话，那么低于框架级别的日志等级的日志信息将不会写入日志缓冲区，就更不可能写出到每种日志记录方式里面去了**。这个在设置框架级别的日志等级和日志记录方式的日志等级的时候需要注意。
3. 该函数是由那些将日志写入日志缓冲区的方法调用的，比如我们介绍过的Emergency, Alert, Critical, Error, Warning, Notice, Informational, Debug等。

**我们总结一下beego的日志模块的结构就是：**

1. 在NewLogger的时候开启协程将日志信息按照每种日志记录方式写出去。
2. 在调用的Emergency, Alert, Critical, Error, Warning, Notice, Informational, Debug等方法时将日志写入到日志缓冲区。
3. beego提供的四种日志记录方式实现的是如何将日志从缓冲区写出去的接口方法。

最后再次回首一下四种日志记录方式所实现的接口：

```go
type loggerType func() LoggerInterface

// LoggerInterface defines the behavior of a log provider.
type LoggerInterface interface {
	Init(config string) error
	WriteMsg(msg string, level int) error
	Destroy()
	Flush()
}
```

|方法|参数|描述|
|---|-------|-----|
|Init|Init(config string) error|从SetLogger方法提供的json格式的字符串初始化日志记录方式|
|WriteMsg|WriteMsg(msg string, level int) error|将日志信息从日志缓冲区写出到对应的方式中。|
|Destroy|Destroy()|销毁该日志记录方式|
|Flush|Flush()|清空日志缓冲区，写出到对应方式中。|

**PS**
再罗嗦一句，beego的日志模块的日志等级有框架级别的日志等级和日志记录方式级别的日志等级。如果框架级别的日志等级高于日志记录方式级别的日志等级，那么以框架级别的日志等级为准，否则以日志记录方式级别的日志等级为准。

从日志等级定义来讲

```go
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
```

LevelEmergency的日志等级最高，LevelDebug的日志等级最低。

这里我们主要对beego的日志模块结构进行了分析，接下来我们会对每种日志记录方式进行分析。
