import '../models/activity_item.dart';
import '../models/book.dart';
import '../models/group.dart';
import '../models/moderation_report.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/user_book.dart';
import '../models/verification.dart';
import '../models/shelf_decor.dart';

/// In-memory sample data for demo mode (screenshots, trailer). Fictional readers,
/// real Open Library works so covers and book pages load.
class DemoStore {
  DemoStore() {
    _seed();
  }

  static const meId = 'demo-me';

  final profiles = <String, Profile>{};
  final books = <String, Book>{};
  final posts = <Post>[];
  final comments = <String, List<Comment>>{};
  final shelves = <String, List<UserBook>>{};
  final groups = <BookGroup>[];
  final groupMembers = <String, Set<String>>{};
  final following = <String, Set<String>>{};
  final likes = <String, Set<String>>{};
  final genres = <String, List<String>>{};
  final activity = <ActivityItem>[];
  final reports = <ModerationReport>[];

  Profile get me => profiles[meId]!;

  static DateTime ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(
        Duration(days: days, hours: hours, minutes: minutes),
      );

  void _seed() {
    void person(
      String id,
      String username,
      String name,
      String bio,
      List<String> g, [
      VerificationKind? verified,
    ]) {
      profiles[id] = Profile(
        id: id,
        username: username,
        displayName: name,
        bio: bio,
        onboardingCompleted: true,
        verifiedAt: verified == null ? null : DateTime(2026, 10, 1),
        verifiedKind: verified,
      );
      genres[id] = g;
    }

    person(
      meId,
      'marie.liest',
      'Marie',
      'Krimis zum Frühstück, Fantasy vor dem Einschlafen. Immer mit Bleistift in der Hand.',
      ['Krimi', 'Fantasy', 'Klassiker'],
    );
    person(
      'u-jonas',
      'jonas_reads',
      'Jonas',
      'Science-Fiction, Sachbuch und zu viele angefangene Bücher.',
      ['Science-Fiction', 'Sachbuch'],
    );
    person(
      'u-lena',
      'lena.seitenweise',
      'Lena',
      'Lesekreis-Gründerin. Klassiker und Gegenwartsliteratur.',
      ['Klassiker', 'Roman'],
    );
    person(
      'u-amir',
      'amir.books',
      'Amir',
      'Ich lese alles, was Drachen oder Raumschiffe hat.',
      ['Fantasy', 'Science-Fiction'],
    );
    person(
      'u-sophie',
      'sophie_zwischendenzeilen',
      'Sophie',
      'Buchhändlerin. Zitate sammeln ist mein Hobby.',
      ['Roman', 'Klassiker', 'Jugendbuch'],
      VerificationKind.bookstore,
    );
    person(
      'u-felix',
      'felix.krimi',
      'Felix',
      'Thriller-Junkie. Spoiler nur mit Warnung!',
      ['Krimi', 'Thriller'],
    );
    person(
      'u-hanna',
      'hanna_liest_vor',
      'Hanna',
      'Lese meinen Kindern vor und mir selbst nachts.',
      ['Jugendbuch', 'Fantasy'],
    );
    person(
      'u-clara',
      'clara.liest',
      'Clara',
      'Krimis, Kaffee und Katzen. Meistens gleichzeitig.',
      ['Krimi', 'Roman'],
    );
    person(
      'u-tom',
      'tom_turns_pages',
      'Tom',
      'Fantasy-Nerd und Hörbuch-Pendler.',
      ['Fantasy', 'Science-Fiction'],
    );
    person(
      'u-yuki',
      'yuki.reads',
      'Yuki',
      'Klassiker im Original, Manga zum Abschalten.',
      ['Klassiker', 'Fantasy'],
    );

    void book(
      String id,
      String title,
      String author,
      String workId,
      int cover,
    ) {
      books[id] = Book(
        id: id,
        title: title,
        author: author,
        openLibraryId: workId,
        coverUrl: 'https://covers.openlibrary.org/b/id/$cover-M.jpg',
      );
    }

    book('b-schwarm', 'Der Schwarm', 'Frank Schätzing', 'OL276211W', 1011136);
    book('b-tschick', 'Tschick', 'Wolfgang Herrndorf', 'OL16621819W', 8418261);
    book('b-parfum', 'Das Parfum', 'Patrick Süskind', 'OL10834W', 10910286);
    book('b-dune', 'Dune', 'Frank Herbert', 'OL893414W', 11481354);
    book(
      'b-mitternacht',
      'Die Mitternachtsbibliothek',
      'Matt Haig',
      'OL20965973W',
      10313767,
    );
    book('b-hobbit', 'Der Hobbit', 'J.R.R. Tolkien', 'OL27482W', 14627509);
    book('b-1984', '1984', 'George Orwell', 'OL1168083W', 9267242);
    book('b-diebin', 'Die Bücherdiebin', 'Markus Zusak', 'OL5819456W', 8153054);
    book(
      'b-hp',
      'Harry Potter und der Stein der Weisen',
      'J.K. Rowling',
      'OL82563W',
      15155833,
    );
    book('b-momo', 'Momo', 'Michael Ende', 'OL2271626W', 8574580);
    book(
      'b-unendlich',
      'Die unendliche Geschichte',
      'Michael Ende',
      'OL2271589W',
      7383413,
    );
    book(
      'b-alchimist',
      'Der Alchimist',
      'Paulo Coelho',
      'OL28954389W',
      12930931,
    );
    book('b-sapiens', 'Sapiens', 'Yuval Noah Harari', 'OL17075811W', 8634250);
    book(
      'b-stolz',
      'Stolz und Vorurteil',
      'Jane Austen',
      'OL20199566W',
      8849495,
    );
    book(
      'b-vorleser',
      'Der Vorleser',
      'Bernhard Schlink',
      'OL14871157W',
      998445,
    );
    book(
      'b-verwandlung',
      'Die Verwandlung',
      'Franz Kafka',
      'OL24823017W',
      11619985,
    );

    profiles[meId] = Profile(
      id: me.id,
      username: me.username,
      displayName: me.displayName,
      bio: me.bio,
      onboardingCompleted: true,
      shelfDecor: const [
        DecorPiece(DecorItem.plant, 0, 3),
        DecorPiece(DecorItem.mug, 1, 0),
        DecorPiece(DecorItem.cat, 2, 3),
      ],
    );

    var n = 0;
    void shelf(
      String user,
      String bookId,
      BookStatus status, [
      int? rating,
      (int, int)? progress,
      int? favorite,
    ]) {
      shelves
          .putIfAbsent(user, () => [])
          .add(
            UserBook(
              id: 'ub-${n++}',
              userId: user,
              bookId: bookId,
              status: status,
              rating: rating,
              book: books[bookId],
              currentPage: progress?.$1,
              pageCount: progress?.$2,
              favoriteRank: favorite,
            ),
          );
    }

    shelf(meId, 'b-mitternacht', BookStatus.reading, null, (187, 320));
    shelf(meId, 'b-dune', BookStatus.reading, null, (112, 704));
    shelf(meId, 'b-schwarm', BookStatus.read, 5, null, 2);
    shelf(meId, 'b-parfum', BookStatus.read, 4, null, 3);
    shelf(meId, 'b-hobbit', BookStatus.read, 5, null, 1);
    shelf(meId, 'b-stolz', BookStatus.read, 4);
    shelf(meId, 'b-1984', BookStatus.unread);
    shelf(meId, 'b-unendlich', BookStatus.unread);
    shelf(meId, 'b-alchimist', BookStatus.abandoned, null, (64, 192));
    shelf(meId, 'b-verwandlung', BookStatus.unread);
    shelf(meId, 'b-diebin', BookStatus.wantToRead);
    shelf(meId, 'b-sapiens', BookStatus.wantToRead);
    shelf(meId, 'b-momo', BookStatus.wantToRead);
    shelf('u-jonas', 'b-dune', BookStatus.read, 5, null, 1);
    shelf('u-jonas', 'b-sapiens', BookStatus.reading);
    shelf('u-jonas', 'b-1984', BookStatus.read, 5);
    shelf('u-lena', 'b-stolz', BookStatus.read, 5);
    shelf('u-lena', 'b-tschick', BookStatus.read, 5);
    shelf('u-lena', 'b-vorleser', BookStatus.reading);
    shelf('u-lena', 'b-verwandlung', BookStatus.read, 4);
    shelf('u-amir', 'b-hobbit', BookStatus.read, 5);
    shelf('u-amir', 'b-dune', BookStatus.reading);
    shelf('u-sophie', 'b-mitternacht', BookStatus.read, 5);
    shelf('u-sophie', 'b-alchimist', BookStatus.read, 3);
    shelf('u-felix', 'b-schwarm', BookStatus.read, 4);
    shelf('u-hanna', 'b-momo', BookStatus.read, 5);
    shelf('u-hanna', 'b-unendlich', BookStatus.reading);
    shelf('u-hanna', 'b-hp', BookStatus.read, 5);
    shelf('u-clara', 'b-parfum', BookStatus.read, 5);
    shelf('u-tom', 'b-hobbit', BookStatus.reading);
    shelf('u-yuki', 'b-stolz', BookStatus.read, 4);

    following[meId] = {'u-jonas', 'u-lena', 'u-sophie', 'u-amir'};
    following['u-jonas'] = {meId, 'u-amir'};
    following['u-lena'] = {meId, 'u-sophie'};
    following['u-sophie'] = {meId};
    following['u-amir'] = {meId, 'u-jonas'};
    following['u-hanna'] = {meId};

    void group(
      String id,
      String creator,
      String name,
      String desc,
      bool private,
      Set<String> members, {
      String? code,
    }) {
      groups.add(
        BookGroup(
          id: id,
          creatorId: creator,
          name: name,
          description: desc,
          isPrivate: private,
          createdAt: ago(days: 30),
          creator: profiles[creator],
          inviteCode: code,
        ),
      );
      groupMembers[id] = members;
    }

    group(
      'g-klassiker',
      'u-lena',
      'Klassiker am Sonntag',
      'Jeden Monat ein Klassiker, jeden Sonntag ein Kapitel. Austen, Kafka, Mann und alles dazwischen.',
      false,
      {'u-lena', meId, 'u-sophie', 'u-jonas', 'u-hanna'},
    );
    group(
      'g-scifi',
      'u-jonas',
      'Sci-Fi & Space Opera',
      'Von Dune bis zur Mitternachtsbibliothek: Wir lesen, was die Zukunft erfindet.',
      false,
      {'u-jonas', 'u-amir', meId},
    );
    group(
      'g-krimi',
      'u-felix',
      'Krimi-Kränzchen',
      'Mordfälle, Plot-Twists und Theorien bis tief in die Nacht.',
      false,
      {'u-felix', 'u-sophie'},
    );
    group(
      'g-fantasy',
      'u-amir',
      'Drachen, Elben & Co.',
      'Fantasy-Lesekreis für alle, die Karten auf den ersten Seiten lieben.',
      false,
      {'u-amir', 'u-hanna', meId, 'u-jonas'},
    );
    group(
      'g-freunde',
      meId,
      'Lesekreis Bammental',
      'Unser privater Kreis: Wein, Snacks und ein Buch im Monat.',
      true,
      {meId, 'u-lena', 'u-sophie'},
      code: 'BAM7Q2',
    );

    void post(
      String id,
      String author,
      PostType type,
      String text,
      Duration age, {
      String? bookId,
      String? groupId,
      int extraLikes = 0,
    }) {
      posts.add(
        Post(
          id: id,
          authorId: author,
          content: text,
          postType: type,
          createdAt: DateTime.now().subtract(age),
          bookId: bookId,
          groupId: groupId,
          author: profiles[author],
          book: bookId == null ? null : books[bookId],
          likeCount: extraLikes,
        ),
      );
    }

    post(
      'p1',
      'u-sophie',
      PostType.quote,
      '„Zwischen Leben und Tod liegt eine Bibliothek.“ Ich habe den Satz dreimal gelesen und dann das Buch zugeklappt, um kurz zu atmen.',
      const Duration(minutes: 18),
      bookId: 'b-mitternacht',
      extraLikes: 23,
    );
    post(
      'p2',
      'u-jonas',
      PostType.review,
      'Dune zum zweiten Mal gelesen und erst jetzt verstanden, wie viel Politik in diesem Wüstenplaneten steckt. Die ersten 100 Seiten sind zäh, danach kann man nicht mehr aufhören. 5 von 5.',
      const Duration(hours: 2),
      bookId: 'b-dune',
      extraLikes: 31,
    );
    post(
      'p3',
      'u-lena',
      PostType.discussion,
      'Frage an alle, die Stolz und Vorurteil gelesen haben: Ist Mr. Darcy wirklich so unsympathisch am Anfang, oder lesen wir ihn nur durch Elizabeths Augen?',
      const Duration(hours: 5),
      bookId: 'b-stolz',
      extraLikes: 12,
    );
    post(
      'p4',
      'u-amir',
      PostType.recommendation,
      'Wer Fantasy liebt und den Hobbit noch nicht kennt: Bitte jetzt nachholen. Gemütlicher wird ein Abenteuer nicht.',
      const Duration(hours: 9),
      bookId: 'b-hobbit',
      extraLikes: 18,
    );
    post(
      'p5',
      meId,
      PostType.review,
      'Der Schwarm hat mich wochenlang nicht losgelassen. Ich schaue das Meer jetzt mit anderen Augen an. Wissenschaftlich, spannend und erschreckend aktuell.',
      const Duration(days: 1, hours: 3),
      bookId: 'b-schwarm',
      extraLikes: 27,
    );
    post(
      'p6',
      'u-hanna',
      PostType.quote,
      '„Zeit ist Leben. Und das Leben wohnt im Herzen.“ Meine Tochter hat beim Vorlesen gefragt, ob die grauen Herren echt sind. Gute Frage.',
      const Duration(days: 1, hours: 8),
      bookId: 'b-momo',
      extraLikes: 40,
    );
    post(
      'p7',
      'u-sophie',
      PostType.recommendation,
      'Für alle, die gerade eine Leseflaute haben: Tschick. 250 Seiten Sommer, Freundschaft und ein geklauter Lada.',
      const Duration(days: 2),
      bookId: 'b-tschick',
      extraLikes: 15,
    );
    post(
      'p8',
      'u-jonas',
      PostType.discussion,
      'Sapiens: Hat jemand das Kapitel über die landwirtschaftliche Revolution gelesen? Größter Betrug der Geschichte, ernsthaft?',
      const Duration(days: 3),
      bookId: 'b-sapiens',
      extraLikes: 9,
    );
    post(
      'g1',
      'u-lena',
      PostType.discussion,
      'Unser Buch für November: Die Verwandlung. Kurz, seltsam, perfekt für einen Sonntag. Wer ist dabei?',
      const Duration(hours: 4),
      groupId: 'g-klassiker',
      bookId: 'b-verwandlung',
      extraLikes: 8,
    );
    post(
      'g2',
      'u-sophie',
      PostType.quote,
      '„Als Gregor Samsa eines Morgens aus unruhigen Träumen erwachte…“ Bester erster Satz der Literatur?',
      const Duration(hours: 20),
      groupId: 'g-klassiker',
      bookId: 'b-verwandlung',
      extraLikes: 11,
    );
    post(
      'g3',
      'u-jonas',
      PostType.discussion,
      'Nächster Monat: Dune oder 1984? Stimmt in den Kommentaren ab!',
      const Duration(hours: 6),
      groupId: 'g-scifi',
      extraLikes: 6,
    );
    post(
      'g4',
      meId,
      PostType.discussion,
      'Treffen am Freitag bei mir, 19 Uhr. Ich backe, ihr bringt eure Lieblingszitate mit.',
      const Duration(hours: 3),
      groupId: 'g-freunde',
      extraLikes: 2,
    );

    likes['p1'] = {meId};
    likes['p6'] = {meId};

    void comment(String postId, String author, String text, Duration age) {
      comments
          .putIfAbsent(postId, () => [])
          .add(
            Comment(
              id: 'c-${comments.length}-$author-${age.inMinutes}',
              postId: postId,
              authorId: author,
              content: text,
              createdAt: DateTime.now().subtract(age),
              author: profiles[author],
            ),
          );
    }

    comment(
      'p1',
      meId,
      'Genau diese Stelle! Ich musste auch eine Pause machen.',
      const Duration(minutes: 12),
    );
    comment(
      'p1',
      'u-lena',
      'Steht jetzt ganz oben auf meiner Liste.',
      const Duration(minutes: 8),
    );
    comment(
      'p1',
      'u-amir',
      'Klingt nach einem Buch für den Lesekreis.',
      const Duration(minutes: 3),
    );
    comment(
      'p2',
      'u-amir',
      'Die ersten 100 Seiten sind wirklich ein Test. Lohnt sich aber!',
      const Duration(hours: 1),
    );
    comment(
      'p2',
      meId,
      'Lese es gerade, bin auf Seite 140. Jetzt wird es spannend.',
      const Duration(minutes: 40),
    );
    comment(
      'p3',
      'u-sophie',
      'Durch Elizabeths Augen, ganz klar. Beim zweiten Lesen mag man ihn sofort.',
      const Duration(hours: 4),
    );
    comment(
      'p5',
      'u-felix',
      'Das Buch hat mir den Urlaub am Strand ruiniert. Im besten Sinne.',
      const Duration(hours: 20),
    );
    comment(
      'g3',
      'u-amir',
      'Dune! Wir brauchen mehr Sandwürmer.',
      const Duration(hours: 5),
    );
    comment(
      'g3',
      meId,
      '1984, passt gerade irgendwie zu gut.',
      const Duration(hours: 2),
    );

    activity.addAll([
      ActivityItem(
        type: ActivityType.like,
        createdAt: ago(minutes: 6),
        actor: profiles['u-lena']!,
        postId: 'p5',
        postPreview: 'Der Schwarm hat mich wochenlang nicht losgelassen.',
      ),
      ActivityItem(
        type: ActivityType.comment,
        createdAt: ago(hours: 1),
        actor: profiles['u-felix']!,
        postId: 'p5',
        postPreview:
            'Das Buch hat mir den Urlaub am Strand ruiniert. Im besten Sinne.',
      ),
      ActivityItem(
        type: ActivityType.follow,
        createdAt: ago(hours: 3),
        actor: profiles['u-hanna']!,
      ),
      ActivityItem(
        type: ActivityType.like,
        createdAt: ago(hours: 5),
        actor: profiles['u-jonas']!,
        postId: 'p5',
        postPreview: 'Der Schwarm hat mich wochenlang nicht losgelassen.',
      ),
      ActivityItem(
        type: ActivityType.follow,
        createdAt: ago(days: 1),
        actor: profiles['u-amir']!,
      ),
    ]);

    reports.add(
      ModerationReport(
        reportId: 'r1',
        reportedAt: ago(hours: 2),
        reason: 'Werbung für illegale E-Book-Downloads',
        reporterUsername: 'lena.seitenweise',
        targetUserId: 'u-spam',
        targetUsername: 'gratis_ebooks_4u',
        targetPostId: 'p-spam',
        content: 'Alle Bestseller kostenlos als PDF!!! Link in meinem Profil',
        contentHidden: true,
      ),
    );
  }

  // ---------- derived views ----------

  Post withState(Post p, String? userId) {
    final liked = likes[p.id] ?? const <String>{};
    return Post(
      id: p.id,
      authorId: p.authorId,
      content: p.content,
      postType: p.postType,
      createdAt: p.createdAt,
      bookId: p.bookId,
      groupId: p.groupId,
      imageUrl: p.imageUrl,
      author: profiles[p.authorId],
      book: p.book,
      likeCount: p.likeCount + liked.length,
      commentCount: comments[p.id]?.length ?? 0,
      likedByMe: userId != null && liked.contains(userId),
    );
  }

  BookGroup groupView(BookGroup g, String? userId) {
    final members = groupMembers[g.id] ?? const <String>{};
    return BookGroup(
      id: g.id,
      creatorId: g.creatorId,
      name: g.name,
      description: g.description,
      genreId: g.genreId,
      isPrivate: g.isPrivate,
      createdAt: g.createdAt,
      memberCount: members.length,
      isMember: userId != null && members.contains(userId),
      creator: g.creator,
      inviteCode: g.creatorId == userId ? g.inviteCode : null,
    );
  }
}
