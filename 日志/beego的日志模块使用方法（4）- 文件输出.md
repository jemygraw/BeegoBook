**文件输出的日志记录方式将日志内容写出到文件，主要是通过控制文件内容行数，文件大小或时间周期来切换日志文件。**

我们看一下实现了`LoggerInterface`的`FileLogWriter`：

```go
type FileLogWriter struct {
	*log.Logger
	mw *MuxWriter
	// 文件名称
	Filename string `json:"filename"`
    // 最大文件行数
	Maxlines          int `json:"maxlines"`
	maxlines_curlines int

	// 按文件大小切换日志文件
	Maxsize         int `json:"maxsize"`
	maxsize_cursize int

	// 按天来切换日志文件
	Daily          bool  `json:"daily"`
	// 单个日志文件保存的最长天数的日志内容
	Maxdays        int64 `json:"maxdays"`
	daily_opendate int
    // 是否切换日志文件
	Rotate bool `json:"rotate"`

	startLock sync.Mutex // Only one log can write to the file
    // 日志记录级别
	Level int `json:"level"`
}
```
我们从上面的结构体定义中可以看出，`FileLogWriter`的可导出成员或者说是支持的参数为：

|名称|json字段|描述|
|------|------|-------|
|Filename|filename|日志文件名|
|Maxlines|maxlines|日志文件最大记录行数|
|Maxsize|maxsize|日志文件最大大小|
|Daily|daily|日志文件按天切换|
|Maxdays|maxdays|日志文件最大的切换周期|
|Rotate|rotate|是否启用日志切换|
|Level|level|日志输出级别|

我们再看一下提供的默认的`FileLogWriter`对象的默认参数：

```go
func NewFileWriter() LoggerInterface {
	w := &FileLogWriter{
		Filename: "",
		Maxlines: 1000000,
		Maxsize:  1 << 28, //256 MB
		Daily:    true,
		Maxdays:  7,
		Rotate:   true,
		Level:    LevelTrace,
	}
	// use MuxWriter instead direct use os.File for lock write when rotate
	w.mw = new(MuxWriter)
	// set MuxWriter as Logger's io.Writer
	w.Logger = log.New(w.mw, "", log.Ldate|log.Ltime)
	return w
}
```
在这个函数中，我们可以看到各个参数的默认值：

|名称|默认值|描述|必填|
|------|-----|------|----|
|Filename|""|文件名为空|YES|
|Maxlines|1000000|100万行|NO|
|Maxsize|1<<28|256M|NO|
|Daily|true|按天切换|NO|
|Maxdays|7|默认每7天切换一次日志|NO|
|Rotate|true|启用日志切换功能|NO|
|Level|LevelTrace|默认级别为Trace|NO|

然后我们看一下`FileLogWriter`所实现的两个方法：

**Init**

```go
func (w *FileLogWriter) Init(jsonconfig string) error {
	err := json.Unmarshal([]byte(jsonconfig), w)
	if err != nil {
		return err
	}
	if len(w.Filename) == 0 {
		return errors.New("jsonconfig must have filename")
	}
	err = w.startLogger()
	return err
}
```
从这个函数中我们可以看出，对于文件输出这种日志记录方式，你必须提供一个日志文件名。

**WriteMsg**

```go
func (w *FileLogWriter) WriteMsg(msg string, level int) error {
	if level > w.Level {
		return nil
	}
	n := 24 + len(msg) // 24 stand for the length "2013/06/23 21:00:22 [T] "
	w.docheck(n)
	w.Logger.Println(msg)
	return nil
}
```
在`WriteMsg()`函数中，我们可以看到在每次输出日志到文件中时，都会调用一个`docheck()`函数，该函数的参数是该次输出的日志信息的长度，而在`docheck()`函数里面，我们将传入的参数累加到日志已有长度中，并且根据日志长度，是否启用日志切换，切换周期等判断日志是否需要切换，如果需要就做切换，如果不需要则累加检查条件，等待下次检测。

我们来看一个例子：

```go
package main

import (
	"github.com/astaxie/beego/logs"
	"time"
)

func main() {
	var chanLen int64 = 1000
	var done chan bool
	logger := logs.NewLogger(chanLen)

	jsonConfig := `{
		"filename":"test.log",
		"maxlines" : 1000,
		"maxsize"  : 10240
	}`
	logger.SetLogger("file", jsonConfig)
	logger.SetLevel(logs.LevelDebug)
	done = make(chan bool)
	go func() {
		for {
			select {
			case <-done:
				break
			default:
				logger.Debug("%s", "this is a debug message")
				logger.Informational("%s", "this is an informational message")
				logger.Notice("%s", "this is a notice message")
			}
		}
	}()
	go func() {
		<-time.After(time.Second * 10)
		done <- true
	}()

	logger.Flush()
	//将日志从缓冲区读出，写入到文件中
	logger.Close()
}
```

在该例子中，我们用一个独立的协程去不断写日志，另外再用一个协程来控制写的时间，两者之间通过`channel`来同步。在这里，我们需要注意的是日志的切换方式，beego的日志切换方式根据`日志文件的行数`，`日志文件的大小`和`日志文件的切换周期`来判断是否切换日志，而启用切换的开关则是`Rotate`这个bool量。上面的三个条件只要有一个条件超过了限定就会切换日志文件。

在上面的例子中，你可以调整`maxlines`和`maxsize`以及`time.After`等待时间来实时体验一下日志文件的切换。
