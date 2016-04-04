require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'session'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todo_complete?(todo)
    todo[:completed]
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo_complete?(todo) }
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, id|
      if todo_complete?(todo)
        complete_todos[todo] = id
      else
        incomplete_todos[todo] = id
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# view all the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The name shoud have a length between 1 and 100'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The name must be unique'
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    'The name shoud have a length between 1 and 100'
  end
end
# create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:id' do |id|
  @list_id = id.to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# edit an existing todo list
get '/lists/:id/edit' do |id|
  @list_id = id.to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# update existing todo list
post '/lists/:id' do |id|
  list_name = params[:list_name].strip
  @list_id = id.to_i
  error = error_for_list_name(list_name)
  @list = session[:lists][@list_id]

  if error =~ /length/ 
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been successfully edited.'
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo list
post '/lists/:id/delete' do |id|
  session[:lists].delete_at(id.to_i)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# mark all todo items in a list as complete
post '/lists/:id/complete_all' do |list_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been completed"
  redirect "/lists/#{list_id}"
end

# Add a new todo item to a todo list
post '/lists/:list_id/todos' do |list_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = 'The new todo has been added'
    redirect "/lists/#{list_id}"
  end
end

#delete a todo item
post '/lists/:list_id/todos/:todo_id/delete' do |list_id, todo_id|
  list = session[:lists][list_id.to_i]
  list[:todos].delete_at(todo_id.to_i)

  session[:success] = 'The todo item has been deleted'
  redirect "lists/#{list_id}"
end

# update the status of a todo item
post '/lists/:list_id/todos/:todo_id' do |list_id, todo_id|
  todo = session[:lists][list_id.to_i][:todos][todo_id.to_i]
  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed    

  session[:success] = 'The todo has been completed'
  redirect "lists/#{list_id}"
end